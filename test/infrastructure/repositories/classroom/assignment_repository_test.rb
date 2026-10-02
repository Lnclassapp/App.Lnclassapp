require "test_helper"

module Repositories
  module Classroom
    # 100 % lignes et branches ; seul l'exercice s'assigne (ADR-0048, ADR-0072 §4.1).
    class AssignmentRepositoryTest < ActiveSupport::TestCase
      Assignable = Entities::Classroom::Assignable

      setup do
        @repository = AssignmentRepository.new
        @classroom = create_classroom
        @teacher = create_teacher
        @at = Time.zone.parse("2026-09-25 10:00")
        @course = create_course(name: "Génétique")
        @essential = create_essential(course: @course, name: "La mitose")
        @exercise = create_exercise(essential: @essential, title: "Quiz mitose")
      end

      def exercise_assignable(record = @exercise, name: nil)
        Assignable.new(type: "Exercise", id: record.id, key: record.public_id, name:)
      end

      def assignment_of(assignable, due_on: nil)
        Entities::Classroom::Assignment.new(id: nil, public_id: nil, classroom_id: @classroom.id, assignable:, status: "active",
                                            assigned_by_id: @teacher.id, assigned_at: @at, archived_at: nil, due_on:)
      end

      test "assigne un exercice, puis le relit actif et par public_id" do
        assignable = exercise_assignable(name: "Quiz mitose")

        created = @repository.create(assignment: assignment_of(assignable)).value

        assert_equal 14, created.public_id.length
        assert_equal created.id, @repository.active_for(classroom_id: @classroom.id, assignable:).id

        found = @repository.find_by_public_id(public_id: created.public_id)

        assert_equal [ "Exercise", @exercise.id, @exercise.public_id, "Quiz mitose" ],
                     found.assignable.to_h.values_at(:type, :id, :key, :name)
        assert found.active?
        assert_equal [ @teacher.id, @at ], [ found.assigned_by_id, found.assigned_at ]
      end

      # ADR-0072 §4.1 : la contrainte de la base refuse une ligne de cours ou de fiche, même écrite hors du domaine.
      test "la base refuse une assignation de cours ou de fiche" do
        [ @course, @essential ].each do |record|
          assert_raises(ActiveRecord::CheckViolation, record.class.name) do
            Orm::ClassroomAssignment.transaction(requires_new: true) do
              Orm::ClassroomAssignment.create!(classroom: @classroom, assignable_type: record.class.name.demodulize,
                                               assignable_id: record.id, assigned_by: @teacher, assigned_at: @at)
            end
          end
        end
      end

      # ADR-0072 §4.3 : l'échéance est écrite une fois, à la création, et relue telle quelle ; nulle sans jours de séance.
      test "écrit l'échéance à la création et la relit, active et par public_id ; sans échéance, elle reste nulle" do
        exercise = Assignable.new(type: "Exercise", id: @exercise.id, key: @exercise.public_id, name: "Quiz mitose")
        due_on = Date.new(2026, 10, 1)

        created = @repository.create(assignment: assignment_of(exercise, due_on:)).value

        assert_equal due_on, created.due_on
        assert_equal due_on, @repository.active_for(classroom_id: @classroom.id, assignable: exercise).due_on
        assert_equal due_on, @repository.find_by_public_id(public_id: created.public_id).due_on
        assert_equal due_on, Orm::ClassroomAssignment.find(created.id).due_on

        other = exercise_assignable(create_exercise(essential: @essential))
        undated = @repository.create(assignment: assignment_of(other)).value

        assert_nil undated.due_on
        assert_nil @repository.find_by_public_id(public_id: undated.public_id).due_on
      end

      test "un exercice déjà assigné et actif donne :conflict ; archivé, il se réassigne en nouvelle ligne" do
        assignable = exercise_assignable
        first = @repository.create(assignment: assignment_of(assignable)).value

        assert_equal({ base: [ :already_assigned ] }, @repository.create(assignment: assignment_of(assignable)).errors)
        assert @repository.archive(id: first.id, archived_by_id: @teacher.id, at: @at)
        assert_nil @repository.active_for(classroom_id: @classroom.id, assignable:)

        archived = @repository.find_by_public_id(public_id: first.public_id)

        assert_equal [ "archived", @at ], [ archived.status, archived.archived_at ]
        assert @repository.create(assignment: assignment_of(assignable)).success?
      end

      test "archiver une assignation déjà archivée ne la change pas" do
        record = create_assignment(classroom: @classroom, assignable: @exercise, status: "archived")
        archived_at = record.archived_at

        @repository.archive(id: record.id, archived_by_id: @teacher.id, at: @at)

        assert_equal archived_at, record.reload.archived_at
      end

      test "rien n'est actif ni trouvé pour une ressource jamais assignée ou un public_id inconnu" do
        assert_nil @repository.active_for(classroom_id: @classroom.id, assignable: exercise_assignable)
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "résout un exercice publié, avec ses parents publiés" do
        resolved = @repository.resolve_assignable(type: "Exercise", key: @exercise.public_id)

        assert_equal [ "Exercise", @exercise.id, @exercise.public_id, "Quiz mitose" ],
                     resolved.assignable.to_h.values_at(:type, :id, :key, :name)
        assert resolved.readable?
        # UDR-0013, amendement du 2026-10-01 : le niveau du cours de l'exercice.
        assert_equal({ level_id: @course.level_id, series_id: @course.series_id }, resolved.course_level)
      end

      test "un exercice dont la fiche ou le cours est un brouillon n'est pas lisible" do
        essential = create_essential(course: create_course(status: "draft"))
        exercise = create_exercise(essential: create_essential(course: @course, status: "draft"))

        assert_not @repository.resolve_assignable(type: "Exercise", key: exercise.public_id).parents_published
        assert_not @repository.resolve_assignable(type: "Exercise", key: create_exercise(essential:).public_id).parents_published
        assert_not @repository.resolve_assignable(type: "Exercise", key: create_exercise(status: "draft").public_id).readable?
      end

      # ADR-0072 §4.1 : resolve_course et resolve_essential ont disparu ; un cours ou une fiche ne se résout plus.
      test "une clé inconnue, un cours, une fiche ou un type hors liste ne résout rien" do
        assert_nil @repository.resolve_assignable(type: "Exercise", key: "inconnue")
        assert_nil @repository.resolve_assignable(type: "Course", key: @course.slug)
        assert_nil @repository.resolve_assignable(type: "Essential", key: @essential.slug)
        assert_nil @repository.resolve_assignable(type: "Classroom", key: @classroom.public_id)
      end

      # ADR-0071 §4.5, §6 : un retrait archive les devoirs actifs que l'enseignant a donnés dans cet établissement, rien d'autre.
      test "archive_all_by_teacher_in_school archive les devoirs actifs de l'enseignant dans cet établissement seulement" do
        school = @classroom.school
        other_classroom = create_classroom(school:)
        second = create_exercise(essential: @essential)
        mine = [ create_assignment(classroom: @classroom, assignable: second, by: @teacher),
                 create_assignment(classroom: other_classroom, assignable: @exercise, by: @teacher) ]
        already = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential), by: @teacher,
                                    status: "archived")
        colleague = create_assignment(classroom: @classroom, assignable: @exercise, by: create_teacher(school:))
        elsewhere = create_assignment(classroom: create_classroom, assignable: second, by: @teacher)
        actor = create_school_admin(school:)
        archived_at = already.reload.archived_at

        assert_equal 2, @repository.archive_all_by_teacher_in_school(teacher_id: @teacher.id, school_id: school.id,
                                                                     archived_by_id: actor.id, at: @at)
        mine.each do |record|
          record.reload
          assert_equal [ "archived", @at, actor.id ], [ record.status, record.archived_at, record.archived_by_id ]
        end
        assert_equal [ archived_at, @teacher.id ], [ already.reload.archived_at, already.archived_by_id ]
        assert_equal "active", colleague.reload.status
        assert_equal "active", elsewhere.reload.status
        assert_equal 0, @repository.archive_all_by_teacher_in_school(teacher_id: @teacher.id, school_id: school.id,
                                                                     archived_by_id: actor.id, at: @at)
      end
    end
  end
end
