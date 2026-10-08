require "test_helper"

module Repositories
  module Classroom
    class ClassroomRepositoryTest < ActiveSupport::TestCase
      setup do
        @school = create_school
        @level = create_level
        @at = Time.zone.parse("2026-09-25 10:00")
        @year = current_school_year
      end

      def classroom(name: "Tle D 1")
        Entities::Classroom::Classroom.new(school_id: @school.id, level_id: @level.id, school_year: @year, name:)
      end

      test "crée une classe avec le jeton de son lien, sans code, et la relit avec ses enseignants et son effectif" do
        created = ClassroomRepository.new.create(classroom: classroom).value
        record = Orm::Classroom.find(created.id)
        teacher = create_teacher(classrooms: [ record ])
        create_student(classroom: record)
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: record, student: create_student, joined_at: @at, left_at: @at)

        found = ClassroomRepository.new.find_by_public_id(public_id: created.public_id)

        assert_match(/\A[0-9a-f]{12}\z/, found.link_token)
        assert_not_respond_to found, :join_code
        assert_equal [ "Tle D 1", @year, "active", 80 ], [ found.name, found.school_year, found.status, found.max_students ]
        assert_equal [ teacher.id ], found.teacher_ids
        assert_equal 1, found.active_students_count
        assert_nil ClassroomRepository.new.find_by_public_id(public_id: "inconnu")
      end

      test "un nom déjà pris dans l'école et l'année donne :conflict sur le nom" do
        create_classroom(school: @school, name: "Tle D 1", school_year: @year)

        result = ClassroomRepository.new.create(classroom: classroom)

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
      end

      test "liste les noms d'une école pour une année" do
        create_classroom(school: @school, name: "6ème 1", school_year: @year)
        create_classroom(school: @school, name: "6ème 2", school_year: "2020-2021")

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
        Orm::ClassroomStudent.create!(joined_via: "standard", classroom: left, student: create_student, joined_at: @at, left_at: @at)
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
        rows = Array.new(1_000) do |index|
          { public_id: SecureRandom.base58(14), school_id: @school.id, school_year: @year, name: "Classe #{index}",
            level_id: @level.id, series_id: nil }
        end

        assert_equal 1_000, ClassroomRepository.new.insert_generated(rows:, at: @at)
        assert_equal 1_000, Orm::Classroom.where(school: @school, created_at: @at).distinct.count(:link_token)
        assert_equal 0, ClassroomRepository.new.insert_generated(rows: [], at: @at)
      end

      test "un nom pris lève RecordNotUnique : le rejeu est l'affaire du moteur" do
        create_classroom(school: @school, name: "Prise", school_year: @year)
        rows = [ { public_id: SecureRandom.base58(14), school_id: @school.id, school_year: @year, name: "Prise",
                   level_id: @level.id, series_id: nil } ]

        assert_raises(ActiveRecord::RecordNotUnique) { ClassroomRepository.new.insert_generated(rows:, at: @at) }
      end

      test "IL-08: verrouille une classe par son identifiant public ou par le jeton de son lien, avec son effectif" do
        record = create_classroom(school: @school)
        create_student(classroom: record)
        repository = ClassroomRepository.new

        by_id = Orm::Classroom.transaction { repository.lock_by_public_id(public_id: record.public_id) }
        by_token = Orm::Classroom.transaction { repository.lock_by_link_token(token: record.reload.link_token) }

        assert_equal [ record.id, record.id ], [ by_id.id, by_token.id ]
        assert_equal [ record.link_token, 1 ], [ by_token.link_token, by_token.active_students_count ]
        assert_nil repository.lock_by_public_id(public_id: "inconnu")
        assert_nil repository.lock_by_link_token(token: "0123456789ab")
        assert_nil repository.lock_by_link_token(token: nil)
      end

      test "IL-11: changer le lien tire un nouveau jeton et invalide l'ancien" do
        record = create_classroom(school: @school).reload
        old = record.link_token
        repository = ClassroomRepository.new

        fresh = repository.rotate_link_token(id: record.id)

        assert_match(/\A[0-9a-f]{12}\z/, fresh)
        assert_not_equal old, fresh
        assert_equal fresh, record.reload.link_token
        assert_nil repository.lock_by_link_token(token: old)
      end
    end
  end
end
