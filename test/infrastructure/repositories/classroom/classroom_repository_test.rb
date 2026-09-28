require "test_helper"

module Repositories
  module Classroom
    class ClassroomRepositoryTest < ActiveSupport::TestCase
      JoinCode = Entities::Classroom::JoinCode

      setup do
        @school = create_school
        @level = create_level
        @at = Time.zone.parse("2026-09-25 10:00")
        @year = current_school_year
      end

      def classroom(name: "Tle D 1")
        Entities::Classroom::Classroom.new(school_id: @school.id, level_id: @level.id, school_year: @year, name:)
      end

      # Les codes que tirerait un Random de graine 7, dans l'ordre.
      def drawn_codes(count)
        random = Random.new(7)
        Array.new(count) { JoinCode.generate(random:) }
      end

      test "crée une classe avec un code d'adhésion valide et la relit avec ses enseignants et son effectif" do
        created = ClassroomRepository.new.create(classroom: classroom).value
        record = Orm::Classroom.find(created.id)
        teacher = create_teacher(classrooms: [ record ])
        create_student(classroom: record)
        Orm::ClassroomStudent.create!(classroom: record, student: create_student, joined_at: @at, left_at: @at)

        found = ClassroomRepository.new.find_by_public_id(public_id: created.public_id)

        assert JoinCode.valid?(found.join_code)
        assert_equal [ "Tle D 1", @year, "active", 80 ], [ found.name, found.school_year, found.status, found.max_students ]
        assert_equal [ teacher.id ], found.teacher_ids
        assert_equal 1, found.active_students_count
        assert_nil ClassroomRepository.new.find_by_public_id(public_id: "inconnu")
      end

      test "un code d'adhésion déjà pris est retiré une fois" do
        taken, fresh = drawn_codes(2)
        create_classroom(school: @school, join_code: taken)

        result = ClassroomRepository.new(random: Random.new(7)).create(classroom: classroom)

        assert result.success?
        assert_equal fresh, result.value.join_code
      end

      test "deux codes pris de suite donnent :conflict sur le code" do
        drawn_codes(2).each { |code| create_classroom(school: @school, join_code: code) }

        result = ClassroomRepository.new(random: Random.new(7)).create(classroom: classroom)

        assert_equal({ join_code: [ :taken ] }, result.errors)
      end

      test "un nom déjà pris dans l'école et l'année donne :conflict sur le nom" do
        create_classroom(school: @school, name: "Tle D 1", school_year: @year)

        result = ClassroomRepository.new.create(classroom: classroom)

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
      end

      test "verrouille une classe par son code, nil si le code est inconnu" do
        record = create_classroom(school: @school)

        locked = Orm::Classroom.transaction { ClassroomRepository.new.lock_by_join_code(join_code: record.join_code) }

        assert_equal record.id, locked.id
        assert_nil ClassroomRepository.new.lock_by_join_code(join_code: "zzz99")
      end

      test "liste les codes pris et les noms d'une école pour une année" do
        record = create_classroom(school: @school, name: "6ème 1", school_year: @year)
        create_classroom(school: @school, join_code: nil, name: "6ème 2", school_year: "2020-2021")

        assert_includes ClassroomRepository.new.taken_join_codes, record.join_code
        assert_not_includes ClassroomRepository.new.taken_join_codes, nil
        assert_equal Set["6ème 1"], ClassroomRepository.new.names_in(school_id: @school.id, school_year: @year)
      end

      test "liste les noms d'un couple niveau/série d'une école pour une année (CN-07)" do
        series = create_series(name: "D")
        create_classroom(school: @school, level: @level, series:, name: "Tle D 1")
        create_classroom(school: @school, level: @level, series:, name: "Tle D 2")
        create_classroom(school: @school, level: @level, name: "Tle 1")
        create_classroom(school: @school, level: @level, series:, name: "Tle D 9", school_year: "2020-2021")
        create_classroom(level: @level, series:, name: "Tle D 3")

        repository = ClassroomRepository.new

        assert_equal [ "Tle D 1", "Tle D 2" ],
                     repository.names_in_level(school_id: @school.id, school_year: @year, level_id: @level.id, series_id: series.id).sort
        assert_equal [ "Tle 1" ], repository.names_in_level(school_id: @school.id, school_year: @year, level_id: @level.id, series_id: nil)
      end

      test "supprime une classe qui n'a jamais servi (CN-05, ADR-0059)" do
        record = create_classroom(school: @school)

        assert ClassroomRepository.new.delete_if_unused(id: record.id).success?
        assert_not Orm::Classroom.exists?(record.id)
        assert_equal :not_found, ClassroomRepository.new.delete_if_unused(id: record.id).code
      end

      test "refuse une classe qui a eu un élève, même parti, un enseignant ou une assignation, même archivée (CN-06)" do
        left = create_classroom(school: @school)
        Orm::ClassroomStudent.create!(classroom: left, student: create_student, joined_at: @at, left_at: @at)
        taught = create_classroom(school: @school)
        create_teacher(school: @school, classrooms: [ taught ])
        assigned = create_classroom(school: @school)
        create_assignment(classroom: assigned, status: "archived")
        repository = ClassroomRepository.new

        assert_equal({ base: [ :has_students ] }, repository.delete_if_unused(id: left.id).errors)
        assert_equal({ base: [ :has_teachers ] }, repository.delete_if_unused(id: taught.id).errors)
        assert_equal({ base: [ :has_assignments ] }, repository.delete_if_unused(id: assigned.id).errors)
        assert_equal :conflict, repository.delete_if_unused(id: left.id).code
        assert_equal 3, Orm::Classroom.where(id: [ left.id, taught.id, assigned.id ]).count
      end

      test "insère 1 000 classes générées d'un coup" do
        codes = JoinCode.generate_unique(count: 1_000, taken: ClassroomRepository.new.taken_join_codes)
        rows = codes.each_with_index.map do |join_code, index|
          { public_id: SecureRandom.base58(14), school_id: @school.id, school_year: @year, name: "Classe #{index}",
            level_id: @level.id, series_id: nil, join_code: }
        end

        assert_equal 1_000, ClassroomRepository.new.insert_generated(rows:, at: @at)
        assert_equal 1_000, Orm::Classroom.where(school: @school, created_at: @at).count
        assert_equal 0, ClassroomRepository.new.insert_generated(rows: [], at: @at)
      end

      test "un code pris lève RecordNotUnique : le rejeu est l'affaire du moteur" do
        taken = create_classroom(school: @school).join_code
        rows = [ { public_id: SecureRandom.base58(14), school_id: @school.id, school_year: @year, name: "Nouvelle",
                   level_id: @level.id, series_id: nil, join_code: taken } ]

        assert_raises(ActiveRecord::RecordNotUnique) { ClassroomRepository.new.insert_generated(rows:, at: @at) }
      end
    end
  end
end
