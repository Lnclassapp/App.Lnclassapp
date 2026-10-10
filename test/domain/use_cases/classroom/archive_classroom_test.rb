require "test_helper"

module UseCases
  module Classroom
    # ADR-0088 : archiver une classe, quel que soit son contenu ; restaurer ; archiver les classes actives d'un niveau.
    # Droits : ManageSchoolStructurePolicy (équipe partout, direction sur son seul établissement actif).
    class ArchiveClassroomTest < ActiveSupport::TestCase
      Clock = Data.define(:now)
      NOW = Time.utc(2026, 10, 10, 10)
      YEAR = "2026-2027".freeze
      ClassroomEntity = Entities::Classroom::Classroom

      # Un seul faux de repository pour les trois cas d'usage : il note ce qui est archivé ou restauré.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :classrooms

        def initialize(classrooms) = @classrooms = classrooms
        def find_by_public_id(public_id:) = @classrooms.find { it.public_id == public_id }

        def archive(id:, at:)
          classroom = @classrooms.find { it.id == id }
          return Shared::Result.failure(:conflict, errors: { base: [ :already_archived ] }) if classroom.archived?

          classroom.status = "archived"
          classroom.archived_at = at
          Shared::Result.success(classroom)
        end

        def restore(id:, at:)
          classroom = @classrooms.find { it.id == id }
          return Shared::Result.failure(:conflict, errors: { base: [ :not_archived ] }) unless classroom.archived?

          classroom.status = "active"
          classroom.archived_at = nil
          Shared::Result.success(classroom)
        end

        def archive_level(school_id:, school_year:, level_id:, at:)
          targets = @classrooms.select { [ it.school_id, it.school_year, it.level_id ] == [ school_id, school_year, level_id ] && it.active? }
          targets.each { archive(id: it.id, at:) }
          targets.size
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

      def classroom(id, name, level_id: 1, school_id: 5, school_year: YEAR, status: "active")
        ClassroomEntity.new(id:, public_id: "cls-#{id}", school_id:, level_id:, school_year:, name:, status:)
      end

      def direction(of:) = Entities::Identity::Actor.new(user_id: 4, role: :school_admin, school_id: of)

      setup do
        @classrooms = FakeClassrooms.new([ classroom(1, "6ème 1"), classroom(2, "6ème 2"), classroom(3, "6ème 3", status: "archived"),
                                           classroom(4, "5ème 1", level_id: 2), classroom(5, "6ème 1", school_id: 9),
                                           classroom(6, "6ème 1", school_year: "2025-2026") ])
        @classrooms.classrooms[2].archived_at = NOW - 1.day
        @schools = FakeSchools.new([ school("lycee", id: 5), school("autre", id: 9), school("ferme", id: 6, status: "inactive") ])
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def build(use_case)
        use_case.new(classrooms: @classrooms, schools: @schools, audit_log: @audit,
                     policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: @transaction, clock: Clock.new(NOW))
      end

      def archive(classroom_public_id, actor: @team, school_public_id: "lycee")
        build(ArchiveClassroom).call(actor:, school_public_id:, classroom_public_id:)
      end

      def restore(classroom_public_id, actor: @team, school_public_id: "lycee")
        build(RestoreClassroom).call(actor:, school_public_id:, classroom_public_id:)
      end

      def archive_level(level_id, actor: @team, school_public_id: "lycee")
        build(ArchiveLevelClassrooms).call(actor:, school_public_id:, level_id:)
      end

      test "l'équipe archive une classe, avec la date d'archivage, et l'archivage est tracé" do
        result = archive("cls-1")

        assert result.success?
        assert_equal [ "archived", NOW ], [ result.value.status, result.value.archived_at ]
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 5,
                         metadata: { change: "classroom_archived", classroom_public_id: "cls-1", name: "6ème 1" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "la direction archive dans son établissement actif, pas ailleurs ni dans un établissement inactif" do
        assert archive("cls-1", actor: direction(of: 5)).success?
        assert_equal :forbidden, archive("cls-5", actor: direction(of: 5), school_public_id: "autre").code
        assert_equal :forbidden, archive("cls-2", actor: direction(of: 6), school_public_id: "ferme").code
        assert_equal 1, @audit.events.size
      end

      test "archiver une classe déjà archivée est un conflit, sans trace" do
        result = archive("cls-3")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :already_archived ] }, result.errors)
        assert_empty @audit.events
      end

      test "classe inconnue, d'un autre établissement ou d'une autre année : :not_found" do
        assert_equal :not_found, archive("inconnue").code
        assert_equal :not_found, archive("cls-5").code
        assert_equal :not_found, archive("cls-6").code
        assert_equal :not_found, archive("cls-1", school_public_id: "inconnu").code
        assert_empty @audit.events
      end

      test "ni enseignant, ni visiteur, ni direction sans établissement : :forbidden" do
        [ Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 5), direction(of: nil), nil ].each do |actor|
          assert_equal :forbidden, archive("cls-1", actor:).code, actor.inspect
        end
        assert_empty @audit.events
      end

      test "restaurer remet la classe active, sans date, et la trace" do
        result = restore("cls-3")

        assert result.success?
        assert_equal [ "active", nil ], [ result.value.status, result.value.archived_at ]
        assert_equal "classroom_restored", @audit.events.first[:metadata][:change]
      end

      test "restaurer une classe active est un conflit ; les droits et l'année valent comme pour l'archivage" do
        assert_equal({ base: [ :not_archived ] }, restore("cls-1").errors)
        assert_equal :forbidden, restore("cls-3", actor: direction(of: 9)).code
        assert_equal :not_found, restore("cls-6").code
        assert_equal :not_found, restore("inconnue").code
        assert_equal :not_found, restore("cls-5").code
        assert_equal :not_found, restore("cls-3", school_public_id: "inconnu").code
        assert_empty @audit.events
      end

      test "archiver un niveau archive ses classes actives de l'année, une seule trace chiffrée" do
        result = archive_level(1)

        assert result.success?
        assert_equal 2, result.value
        assert_equal %w[archived archived archived active], @classrooms.classrooms.first(4).map(&:status)
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 5,
                         metadata: { change: "level_archived", level_id: 1, classrooms_count: 2 } } ], @audit.events
      end

      test "un niveau sans classe active est un conflit ; droits comme pour une classe" do
        archive_level(1)
        @audit.events.clear

        assert_equal({ base: [ :nothing_to_archive ] }, archive_level(1).errors)
        assert_equal :forbidden, archive_level(2, actor: direction(of: 9)).code
        assert_equal :not_found, archive_level(2, school_public_id: "inconnu").code
        assert_empty @audit.events
      end
    end
  end
end
