require "test_helper"

module Repositories
  module Classroom
    # 100 % lignes et branches, pour chacun des trois types de ressource (ADR-0048).
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

      def resources
        { "Course" => [ @course, @course.slug, "Génétique" ],
          "Essential" => [ @essential, @essential.slug, "La mitose" ],
          "Exercise" => [ @exercise, @exercise.public_id, "Quiz mitose" ] }
      end

      def assignment_of(assignable)
        Entities::Classroom::Assignment.new(id: nil, public_id: nil, classroom_id: @classroom.id, assignable:, status: "active",
                                            assigned_by_id: @teacher.id, assigned_at: @at, archived_at: nil)
      end

      test "assigne chaque type de ressource, puis la relit active et par public_id" do
        resources.each do |type, (record, key, name)|
          assignable = Assignable.new(type:, id: record.id, key:, name:)

          created = @repository.create(assignment: assignment_of(assignable)).value

          assert_equal 14, created.public_id.length, type
          assert_equal created.id, @repository.active_for(classroom_id: @classroom.id, assignable:).id, type

          found = @repository.find_by_public_id(public_id: created.public_id)

          assert_equal [ type, record.id, key, name ], found.assignable.to_h.values_at(:type, :id, :key, :name), type
          assert found.active?, type
          assert_equal [ @teacher.id, @at ], [ found.assigned_by_id, found.assigned_at ], type
        end
      end

      test "une ressource déjà assignée et active donne :conflict ; archivée, elle se réassigne en nouvelle ligne" do
        resources.each do |type, (record, key, _name)|
          assignable = Assignable.new(type:, id: record.id, key:)
          first = @repository.create(assignment: assignment_of(assignable)).value

          assert_equal({ base: [ :already_assigned ] }, @repository.create(assignment: assignment_of(assignable)).errors, type)
          assert @repository.archive(id: first.id, archived_by_id: @teacher.id, at: @at)
          assert_nil @repository.active_for(classroom_id: @classroom.id, assignable:), type

          archived = @repository.find_by_public_id(public_id: first.public_id)

          assert_equal [ "archived", @at ], [ archived.status, archived.archived_at ], type
          assert @repository.create(assignment: assignment_of(assignable)).success?, type
        end
      end

      test "archiver une assignation déjà archivée ne la change pas" do
        record = create_assignment(classroom: @classroom, assignable: @course, status: "archived")
        archived_at = record.archived_at

        @repository.archive(id: record.id, archived_by_id: @teacher.id, at: @at)

        assert_equal archived_at, record.reload.archived_at
      end

      test "rien n'est actif ni trouvé pour une ressource jamais assignée ou un public_id inconnu" do
        assert_nil @repository.active_for(classroom_id: @classroom.id, assignable: Assignable.new(type: "Course", id: @course.id, key: "x"))
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "résout chaque type de ressource publiée, avec ses parents publiés" do
        resources.each do |type, (record, key, name)|
          resolved = @repository.resolve_assignable(type:, key:)

          assert_equal [ type, record.id, key, name ], resolved.assignable.to_h.values_at(:type, :id, :key, :name), type
          assert resolved.readable?, type
        end
      end

      test "une fiche ou un exercice dont un parent est un brouillon n'est pas lisible" do
        draft_course = create_course(status: "draft")
        essential = create_essential(course: draft_course)
        exercise = create_exercise(essential: create_essential(course: @course, status: "draft"))

        assert_not @repository.resolve_assignable(type: "Course", key: draft_course.slug).readable?
        assert_not @repository.resolve_assignable(type: "Essential", key: essential.slug).parents_published
        assert_not @repository.resolve_assignable(type: "Exercise", key: exercise.public_id).parents_published
        assert_not @repository.resolve_assignable(type: "Exercise", key: create_exercise(essential:).public_id).parents_published
      end

      test "une clé inconnue ou un type hors liste ne résout rien" do
        %w[Course Essential Exercise].each { |type| assert_nil @repository.resolve_assignable(type:, key: "inconnue") }
        assert_nil @repository.resolve_assignable(type: "Classroom", key: @classroom.public_id)
      end
    end
  end
end
