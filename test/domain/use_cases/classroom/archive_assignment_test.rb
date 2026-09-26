require "test_helper"

module UseCases
  module Classroom
    # CL-16, CL-17, CL-20, AS-19 (ADR-0048) : retirer archive la ligne, qui n'est jamais supprimée ; le port n'offre
    # d'ailleurs aucune suppression.
    class ArchiveAssignmentTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Assignment = Entities::Classroom::Assignment

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(*classrooms)
          @stored = classrooms
        end

        def find_by_public_id(public_id:) = @stored.find { it.public_id == public_id }
      end

      class FakeAssignments
        include Ports::Classroom::AssignmentRepositoryPort

        attr_reader :archived

        def initialize(*assignments)
          @stored = assignments
          @archived = []
        end

        def find_by_public_id(public_id:) = @stored.find { it.public_id == public_id }

        def archive(id:, archived_by_id:, at:)
          @archived << [ id, archived_by_id, at ]
          true
        end
      end

      setup do
        @classroom = Entities::Classroom::Classroom.new(id: 3, public_id: "cls6e1", name: "6ème 1", teacher_ids: [ 7 ])
        @other = Entities::Classroom::Classroom.new(id: 5, public_id: "cls6e3", name: "6ème 3", teacher_ids: [ 7 ])
        archived_classroom = Entities::Classroom::Classroom.new(id: 4, public_id: "clsold", teacher_ids: [ 7 ], status: "archived")
        meiose = Entities::Classroom::Assignable.new(type: "Exercise", id: 30, key: "ex-meiose", name: "Méiose")
        @assignments = FakeAssignments.new(
          assignment(1, "asgactive", 3, meiose),
          assignment(2, "asgarchived", 3, meiose, status: "archived", archived_at: NOW - 3600),
          assignment(3, "asgold", 4, meiose)
        )
        @classrooms = FakeClassrooms.new(@classroom, @other, archived_classroom)
        @teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)
      end

      def assignment(id, public_id, classroom_id, assignable, status: "active", archived_at: nil)
        Assignment.new(id:, public_id:, classroom_id:, assignable:, status:, assigned_by_id: 7, assigned_at: NOW - 7200, archived_at:)
      end

      def archive(public_id, classroom: "cls6e1", actor: @teacher)
        ArchiveAssignment.new(classrooms: @classrooms, assignments: @assignments, policy: Policies::Classroom::AssignPolicy.new,
                              clock: Clock.new(NOW)).call(actor:, classroom_public_id: classroom, public_id:)
      end

      test "archive l'assignation active, par l'utilisateur connecté, et la rend archivée avec sa classe" do
        result = archive("asgactive")

        assert result.success?
        assert_equal [ [ 1, 7, NOW ] ], @assignments.archived
        assert_equal [ "asgactive", "archived", NOW, "Méiose" ],
                     result.value.assignment.then { [ it.public_id, it.status, it.archived_at, it.assignable.name ] }
        assert_same @classroom, result.value.classroom
      end

      test "l'équipe peut retirer" do
        team = Entities::Identity::Actor.new(user_id: 99, role: :team, team_role: "content")

        assert archive("asgactive", actor: team).success?
        assert_equal [ [ 1, 99, NOW ] ], @assignments.archived
      end

      test "déjà archivée : :conflict (already_archived), rien n'est écrit" do
        result = archive("asgarchived")

        assert_equal [ :conflict, { base: [ :already_archived ] } ], [ result.code, result.errors ]
        assert_empty @assignments.archived
      end

      test "une assignation inconnue, ou d'une autre classe que celle annoncée, est introuvable" do
        assert_equal :not_found, archive("inconnue").code
        assert_equal :not_found, archive("asgactive", classroom: "cls6e3").code
        assert_equal :not_found, archive("asgactive", classroom: "inconnue").code
        assert_empty @assignments.archived
      end

      test "une classe qu'on n'enseigne pas, ou archivée : :forbidden, rien n'est écrit" do
        stranger = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 1)

        assert_equal :forbidden, archive("asgactive", actor: stranger).code
        assert_equal :forbidden, archive("asgactive", actor: nil).code
        assert_equal [ :forbidden, [ :classroom_archived ] ], archive("asgold", classroom: "clsold").then { [ it.code, it.errors[:base] ] }
        assert_empty @assignments.archived
      end
    end
  end
end
