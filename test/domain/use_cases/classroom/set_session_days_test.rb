require "test_helper"

module UseCases
  module Classroom
    # ADR-0072 §4.2, UDR-0062 §3.4 : l'enseignant de la classe modifie ses jours de séance ; les échéances déjà données
    # ne bougent pas ; tout décocher revient à « non renseigné ».
    class SetSessionDaysTest < ActiveSupport::TestCase
      NOW = ActiveSupport::TimeZone["Africa/Abidjan"].local(2026, 10, 5, 10)
      Clock = Data.define(:now)

      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        def initialize(*classrooms)
          @stored = classrooms
        end

        def find_by_public_id(public_id:) = @stored.find { it.public_id == public_id }
      end

      class FakeSessionDays
        include Ports::Classroom::SessionDaysRepositoryPort

        attr_reader :stored

        def initialize(stored = {})
          @stored = stored
        end

        def for(teacher_id:, classroom_id:) = Entities::Classroom::SessionDays.new(weekdays: @stored.fetch([ teacher_id, classroom_id ], []))

        def replace(teacher_id:, classroom_id:, weekdays:, at:)
          @stored[[ teacher_id, classroom_id ]] = weekdays
          true
        end
      end

      setup do
        @classroom = Entities::Classroom::Classroom.new(id: 3, public_id: "cls3b", name: "3ème B", teacher_ids: [ 7 ], level_id: 4)
        archived = Entities::Classroom::Classroom.new(id: 4, public_id: "clsold", name: "3ème A", teacher_ids: [ 7 ], level_id: 4,
                                                      status: "archived")
        @classrooms = FakeClassrooms.new(@classroom, archived)
        @session_days = FakeSessionDays.new([ 7, 3 ] => [ 1, 4 ])
        @teacher = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)
      end

      def set(weekdays, classroom: "cls3b", actor: @teacher)
        dto = Dtos::Classroom::SessionDaysInput.new(classroom_public_id: classroom, weekdays:)
        SetSessionDays.new(classrooms: @classrooms, session_days: @session_days, policy: Policies::Classroom::SetSessionDaysPolicy.new,
                           clock: Clock.new(NOW)).call(actor:, dto:)
      end

      test "remplace les jours de l'enseignant et rend la classe avec ses nouveaux jours" do
        result = set(%w[2 5])

        assert result.success?
        assert_same @classroom, result.value.classroom
        assert_equal [ 2, 5 ], result.value.session_days.weekdays
        assert_equal [ 2, 5 ], @session_days.stored[[ 7, 3 ]]
      end

      # Le use case ne reçoit aucun repository d'assignation : il ne peut pas toucher à une échéance déjà donnée.
      test "ne dépend d'aucune assignation : les échéances déjà données ne bougent pas" do
        keywords = SetSessionDays.instance_method(:initialize).parameters.map(&:last)

        assert_equal %i[classrooms session_days policy clock], keywords
      end

      test "tout décocher vaut « non renseigné » : aucun jour" do
        result = set([ "" ])

        assert result.success?
        assert result.value.session_days.none?
        assert_equal [], @session_days.stored[[ 7, 3 ]]
      end

      test "un jour hors de lundi … samedi : :invalid, rien n'est écrit" do
        result = set(%w[1 7])

        assert_equal :invalid, result.code
        assert result.errors.key?(:weekdays)
        assert_equal [ 1, 4 ], @session_days.stored[[ 7, 3 ]]
      end

      test "refus : l'équipe, un autre enseignant, un élève, un visiteur, une classe archivée ; rien n'est écrit" do
        team = Entities::Identity::Actor.new(user_id: 99, role: :team, team_role: "content")
        stranger = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 1)
        student = Entities::Identity::Actor.new(user_id: 7, role: :student)

        [ team, stranger, student, nil ].each { |actor| assert_equal :forbidden, set(%w[2], actor:).code, actor.inspect }
        assert_equal [ :forbidden, [ :classroom_archived ] ], set(%w[2], classroom: "clsold").then { [ it.code, it.errors[:base] ] }
        assert_equal({ [ 7, 3 ] => [ 1, 4 ] }, @session_days.stored)
      end

      test "une classe inconnue est introuvable" do
        assert_equal :not_found, set(%w[2], classroom: "inconnue").code
      end
    end
  end
end
