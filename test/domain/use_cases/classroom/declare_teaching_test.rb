require "test_helper"

module UseCases
  module Classroom
    # CL-09 : un enseignant se déclare dans une classe active de son école principale, et seulement celle-là.
    class DeclareTeachingTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      ClassroomEntity = Entities::Classroom::Classroom

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(*classrooms) = @classrooms = classrooms
        def find_by_public_id(public_id:) = @classrooms.find { it.public_id == public_id }
      end

      # Idempotent comme le vrai dépôt : une seconde déclaration répond :already sans rien écrire.
      class FakeTeachings
        include Ports::Classroom::TeachingRepositoryPort

        attr_reader :declared

        def initialize
          @declared = []
        end

        def declare(teacher_id:, classroom_id:, at:)
          return :already if @declared.any? { it[0, 2] == [ teacher_id, classroom_id ] }

          @declared << [ teacher_id, classroom_id, at ]
          :created
        end
      end

      setup do
        @sixth = ClassroomEntity.new(id: 11, public_id: "cls-6e1", school_id: 31, level_id: 1, school_year: "2026-2027",
                                     name: "6ème 1")
        @other_school = ClassroomEntity.new(id: 12, public_id: "cls-autre", school_id: 32, level_id: 1,
                                            school_year: "2026-2027", name: "6ème 1")
        @archived = ClassroomEntity.new(id: 13, public_id: "cls-arch", school_id: 31, level_id: 1, school_year: "2026-2027",
                                        name: "6ème 9", status: "archived")
        @teachings = FakeTeachings.new
        @teacher = Entities::Identity::Actor.new(user_id: 5, role: :teacher, school_id: 31)
      end

      def declare(public_id, actor: @teacher)
        DeclareTeaching.new(classrooms: FakeClassrooms.new(@sixth, @other_school, @archived), teachings: @teachings,
                            policy: Policies::Classroom::DeclareTeachingPolicy.new, clock: Clock.new(NOW))
                       .call(actor:, classroom_public_id: public_id)
      end

      test "déclare l'enseignant dans une classe active de son école, à l'heure de l'horloge" do
        result = declare("cls-6e1")

        assert result.success?
        assert_equal @sixth, result.value
        assert_equal [ [ 5, 11, NOW ] ], @teachings.declared
      end

      test "déclarer deux fois la même classe réussit sans doublon" do
        declare("cls-6e1")
        result = declare("cls-6e1")

        assert result.success?
        assert_equal [ [ 5, 11, NOW ] ], @teachings.declared
      end

      test "une classe d'une autre école : refus, rien n'est écrit" do
        result = declare("cls-autre")

        assert_equal :forbidden, result.code
        assert_equal({ base: [ :other_school ] }, result.errors)
        assert_empty @teachings.declared
      end

      test "une classe archivée : refus, rien n'est écrit" do
        result = declare("cls-arch")

        assert_equal :forbidden, result.code
        assert_equal({ base: [ :classroom_archived ] }, result.errors)
        assert_empty @teachings.declared
      end

      test "hors du rôle enseignant : refus" do
        assert_equal :forbidden, declare("cls-6e1", actor: Entities::Identity::Actor.new(user_id: 7, role: :team)).code
        assert_equal :forbidden, declare("cls-6e1", actor: nil).code
        assert_empty @teachings.declared
      end

      test "une classe inconnue : :not_found" do
        assert_equal :not_found, declare("cls-inconnue").code
        assert_empty @teachings.declared
      end
    end
  end
end
