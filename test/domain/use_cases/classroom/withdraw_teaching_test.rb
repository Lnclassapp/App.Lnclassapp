require "test_helper"

module UseCases
  module Classroom
    # CL-09 : se retirer d'une classe supprime la déclaration, et rien d'autre (assignations et sessions restent).
    class WithdrawTeachingTest < ActiveSupport::TestCase
      ClassroomEntity = Entities::Classroom::Classroom

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(*classrooms) = @classrooms = classrooms
        def find_by_public_id(public_id:) = @classrooms.find { it.public_id == public_id }
      end

      # Le port n'offre que `withdraw` : le use case ne peut toucher ni aux assignations ni aux sessions.
      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        attr_reader :pairs

        def initialize(*pairs) = @pairs = pairs

        def withdraw(teacher_id:, classroom_id:)
          @pairs.delete([ teacher_id, classroom_id ])
          true
        end
      end

      setup do
        @sixth = ClassroomEntity.new(id: 11, public_id: "cls-6e1", school_id: 31, level_id: 1, school_year: "2026-2027",
                                     name: "6ème 1", teacher_ids: [ 5 ])
        @other_school = ClassroomEntity.new(id: 12, public_id: "cls-autre", school_id: 32, level_id: 1,
                                            school_year: "2026-2027", name: "6ème 1", teacher_ids: [ 5 ])
        @archived = ClassroomEntity.new(id: 13, public_id: "cls-arch", school_id: 31, level_id: 1, school_year: "2026-2027",
                                        name: "6ème 9", status: "archived", teacher_ids: [ 5 ])
        @teachings = FakeTeachings.new([ 5, 11 ], [ 5, 12 ], [ 5, 13 ], [ 6, 11 ])
        @teacher = Entities::Identity::Actor.new(user_id: 5, role: :teacher, school_id: 31)
      end

      def withdraw(public_id, actor: @teacher)
        WithdrawTeaching.new(classrooms: FakeClassrooms.new(@sixth, @other_school, @archived), teachings: @teachings,
                             policy: Policies::Classroom::DeclareTeachingPolicy.new)
                        .call(actor:, classroom_public_id: public_id)
      end

      test "retire l'enseignant de la classe, sans toucher aux autres enseignants" do
        result = withdraw("cls-6e1")

        assert result.success?
        assert_equal @sixth, result.value
        assert_equal [ [ 5, 12 ], [ 5, 13 ], [ 6, 11 ] ], @teachings.pairs
      end

      test "retirer une classe non déclarée réussit sans rien changer" do
        withdraw("cls-6e1")

        assert withdraw("cls-6e1").success?
        assert_equal [ [ 5, 12 ], [ 5, 13 ], [ 6, 11 ] ], @teachings.pairs
      end

      test "une classe d'une autre école ou archivée : refus, la déclaration reste" do
        assert_equal :forbidden, withdraw("cls-autre").code
        assert_equal :forbidden, withdraw("cls-arch").code
        assert_equal [ [ 5, 11 ], [ 5, 12 ], [ 5, 13 ], [ 6, 11 ] ], @teachings.pairs
      end

      test "hors du rôle enseignant : refus" do
        assert_equal :forbidden, withdraw("cls-6e1", actor: Entities::Identity::Actor.new(user_id: 5, role: :student)).code
        assert_equal :forbidden, withdraw("cls-6e1", actor: nil).code
        assert_equal 4, @teachings.pairs.size
      end

      test "une classe inconnue : :not_found" do
        assert_equal :not_found, withdraw("cls-inconnue").code
        assert_equal 4, @teachings.pairs.size
      end
    end
  end
end
