require "test_helper"

module UseCases
  module Classroom
    # CN-05, CN-06, CN-07, CN-09, ADR-0059 : « − » du bloc « Classes par niveau » supprime la dernière classe du couple
    # niveau/série si elle n'a jamais servi ; sinon il refuse, sans rien supprimer ni tracer.
    class RemoveLevelClassroomTest < ActiveSupport::TestCase
      Clock = Data.define(:now)
      NOW = Time.utc(2026, 9, 28, 10)
      YEAR = "2026-2027".freeze
      ClassroomEntity = Entities::Classroom::Classroom

      # `used` : { id => raison } des classes qui ont servi.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :classrooms, :deleted

        def initialize(classrooms, used: {})
          @classrooms = classrooms
          @used = used
          @deleted = []
        end

        def find_by_public_id(public_id:) = @classrooms.find { it.public_id == public_id }

        def names_in_level(school_id:, school_year:, level_id:, series_id:)
          @classrooms.select { [ it.school_id, it.school_year, it.level_id, it.series_id ] == [ school_id, school_year, level_id, series_id ] }
                     .map(&:name)
        end

        def delete_if_unused(id:)
          return Shared::Result.failure(:conflict, errors: { base: [ @used[id] ] }) if @used.key?(id)

          @deleted << id
          @classrooms.reject! { it.id == id }
          Shared::Result.success
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(schools) = @schools = schools
        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize = @events = []
        def record(**event) = (@events << event) && true
      end

      def school(public_id, id:, status: "active")
        Entities::School::School.new(id:, public_id:, drena_id: 1, name: "Lycée Classique", school_type: "public", cycle: "both", status:)
      end

      def classroom(id, name, level_id: 1, series_id: nil, school_id: 5, school_year: YEAR)
        ClassroomEntity.new(id:, public_id: "cls-#{id}", school_id:, level_id:, series_id:, school_year:, name:, status: "active")
      end

      setup do
        @classrooms = FakeClassrooms.new(
          [ classroom(1, "6ème 1"), classroom(2, "6ème 2"), classroom(3, "6ème 10"), classroom(4, "Tle D 1", level_id: 7, series_id: 105),
            classroom(5, "Tle D 2", level_id: 7, series_id: 105), classroom(6, "6ème 1", school_year: "2025-2026"),
            classroom(7, "6ème 1", school_id: 9) ],
          used: { 5 => :has_students }
        )
        @schools = FakeSchools.new([ school("lycee", id: 5), school("brouillon", id: 8, status: "draft"), school("autre", id: 9) ])
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def remove(classroom_public_id, actor: @team, school_public_id: "lycee")
        RemoveLevelClassroom.new(classrooms: @classrooms, schools: @schools, audit_log: @audit,
                                 policy: Policies::Classroom::ManageClassroomPolicy.new, transaction: @transaction,
                                 clock: Clock.new(NOW))
                            .call(actor:, school_public_id:, classroom_public_id:)
      end

      test "la dernière classe du niveau, jamais utilisée, est supprimée et le retrait est tracé" do
        result = remove("cls-3")

        assert result.success?
        assert_equal "6ème 10", result.value.name
        assert_equal [ 3 ], @classrooms.deleted
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 5,
                         metadata: { change: "classroom_removed", classroom_public_id: "cls-3", name: "6ème 10" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "une classe qui a servi est refusée avec sa raison : rien n'est supprimé ni tracé" do
        result = remove("cls-5")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :has_students ] }, result.errors)
        assert_empty @classrooms.deleted
        assert_empty @audit.events
      end

      test "une classe qui n'est plus la dernière de son niveau est refusée" do
        result = remove("cls-2")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :not_last ] }, result.errors)
        assert_empty @classrooms.deleted
      end

      test "tout statut d'établissement : un brouillon peut être ajusté" do
        @classrooms.classrooms << classroom(8, "6ème 1", school_id: 8)

        assert remove("cls-8", school_public_id: "brouillon").success?
      end

      test "une classe inconnue, d'un autre établissement ou d'une autre année donne :not_found" do
        assert_equal :not_found, remove("inconnue").code
        assert_equal :not_found, remove("cls-7").code
        assert_equal :not_found, remove("cls-6").code
        assert_equal :not_found, remove("cls-3", school_public_id: "inconnu").code
        assert_empty @classrooms.deleted
      end

      test "hors de l'équipe : :forbidden, rien n'est supprimé" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 5)

        assert_equal :forbidden, remove("cls-3", actor: teacher).code
        assert_equal :forbidden, remove("cls-3", actor: nil).code
        assert_empty @classrooms.deleted
        assert_empty @audit.events
      end
    end
  end
end
