require "test_helper"

module UseCases
  module Classroom
    # ADR-0098 : modifier une classe — seul le suffixe du nom (après le préfixe du barème) et le plafond changent.
    # Droits : ManageSchoolStructurePolicy (équipe partout, direction sur son seul établissement actif) ; pas l'enseignant.
    class UpdateClassroomTest < ActiveSupport::TestCase
      Clock = Data.define(:now)
      NOW = Time.utc(2026, 10, 16, 10)
      YEAR = "2026-2027".freeze
      SIXTH = 1 # TaxonomyFixture : « 6ème »
      TLE = 7 # « Tle »
      SERIES_D = 105 # « D »
      ClassroomEntity = Entities::Classroom::Classroom
      Input = Dtos::Classroom::ClassroomSettingsInput

      # Note chaque écriture ; un refus programmé (below_headcount, taken) ressort tel quel, comme le ferait le repository.
      class FakeClassrooms
        include Ports::Classroom::ClassroomRepositoryPort

        attr_reader :classrooms, :writes
        # refusal : le refus programmé. locked_state : l'état lu sous le verrou si une autre écriture a passé entre-temps.
        attr_accessor :refusal, :locked_state

        def initialize(classrooms, journal: [])
          @classrooms = classrooms
          @writes = []
          @journal = journal
        end

        def find_by_public_id(public_id:) = @classrooms.find { it.public_id == public_id }

        def update_settings(id:, name:, max_students:)
          @journal << :write
          @writes << { id:, name:, max_students: }
          return refusal if refusal

          classroom = @classrooms.find { it.id == id }
          after = ClassroomEntity.new(id:, public_id: classroom.public_id, school_id: classroom.school_id,
                                      level_id: classroom.level_id, school_year: classroom.school_year, name:, max_students:)
          before = locked_state || classroom
          Shared::Result.success(Ports::Classroom::ClassroomRepositoryPort::SettingsChange.new(before:, after:))
        end
      end

      # Journalise le début et la fin de la transaction, et les traces écrites dedans.
      class JournalingTransaction
        include Ports::Shared::TransactionPort

        def initialize(journal) = @journal = journal

        def call
          @journal << :begin
          yield.tap { @journal << :commit }
        end
      end

      class JournalingAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def initialize(journal)
          @journal = journal
          @events = []
        end

        def record(**event)
          @journal << :audit
          (@events << event) && true
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(schools) = @schools = schools
        def find_by_public_id(public_id:) = @schools.find { it.public_id == public_id }
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def lookup = Entities::Catalog::TaxonomyFixture.lookup
      end

      def school(public_id, id:, status: "active")
        Entities::School::School.new(id:, public_id:, drena_id: 1, name: "Lycée Classique", school_type: "public", cycle: "both", status:)
      end

      def classroom(id, name, level_id: SIXTH, series_id: nil, school_id: 5, school_year: YEAR, status: "active", max_students: 80)
        ClassroomEntity.new(id:, public_id: "cls-#{id}", school_id:, level_id:, series_id:, school_year:, name:, status:, max_students:)
      end

      def direction(of:) = Entities::Identity::Actor.new(user_id: 4, role: :school_admin, school_id: of)

      setup do
        @classrooms = FakeClassrooms.new([ classroom(1, "6ème 3"), classroom(2, "Tle D 2", level_id: TLE, series_id: SERIES_D),
                                           classroom(3, "6ème 4", status: "archived"), classroom(4, "6ème 1", school_id: 9),
                                           classroom(5, "6ème 1", school_year: "2025-2026"), classroom(6, "Bilingue"),
                                           classroom(7, "6ème A") ])
        @schools = FakeSchools.new([ school("lycee", id: 5), school("autre", id: 9), school("ferme", id: 6, status: "inactive") ])
        @audit = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field")
      end

      def update(classroom_public_id, suffix: "A", max_students: "95", actor: @team, school_public_id: "lycee")
        UpdateClassroom.new(classrooms: @classrooms, schools: @schools, taxonomy: FakeTaxonomy.new, audit_log: @audit,
                            policy: Policies::School::ManageSchoolStructurePolicy.new, transaction: @transaction, clock: Clock.new(NOW))
                       .call(actor:, school_public_id:, classroom_public_id:, dto: Input.new(suffix:, max_students:))
      end

      test "l'équipe renomme « 6ème 3 » en « 6ème A » et relève son plafond : écrit sous transaction et tracé" do
        result = update("cls-1")

        assert result.success?
        assert_equal [ "6ème A", 95 ], [ result.value.name, result.value.max_students ]
        assert_equal [ { id: 1, name: "6ème A", max_students: 95 } ], @classrooms.writes
        assert_equal [ { action: "school.changed", actor_id: 7, at: NOW, subject_type: "School", subject_id: 5,
                         metadata: { change: "classroom_updated", classroom_public_id: "cls-1", name: "6ème A", previous_name: "6ème 3",
                                     max_students: 95, previous_max_students: 80 } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      def trace_of(metadata) = @audit.events.map { |e| e[:metadata].values_at(*metadata) }

      test "le nom seul change : une écriture, une trace" do
        result = update("cls-2", suffix: "3", max_students: "80")

        assert result.success?
        assert_equal [ { id: 2, name: "Tle D 3", max_students: 80 } ], @classrooms.writes
        assert_equal [ [ "Tle D 3", "Tle D 2", 80, 80 ] ],
                     trace_of(%i[name previous_name max_students previous_max_students])
      end

      test "le plafond seul change : une écriture, une trace" do
        result = update("cls-7", suffix: "A", max_students: "95")

        assert result.success?
        assert_equal [ { id: 7, name: "6ème A", max_students: 95 } ], @classrooms.writes
        assert_equal [ [ "6ème A", "6ème A", 95, 80 ] ],
                     trace_of(%i[name previous_name max_students previous_max_students])
      end

      test "la trace garde l'état lu sous le verrou, pas celui lu avant lui" do
        @classrooms.locked_state = classroom(1, "6ème B", max_students: 70)

        update("cls-1")

        assert_equal [ [ "6ème B", 70 ] ], trace_of(%i[previous_name previous_max_students])
      end

      test "la trace s'écrit dans la transaction, après l'écriture ; un refus ou rien de changé n'en laisse aucune" do
        journal = []
        @classrooms = FakeClassrooms.new(@classrooms.classrooms, journal:)
        @transaction = JournalingTransaction.new(journal)
        @audit = JournalingAuditLog.new(journal)

        update("cls-1")
        assert_equal %i[begin write audit commit], journal

        journal.clear
        update("cls-1", suffix: "3", max_students: "80")
        assert_empty journal, "rien de changé : ni transaction, ni écriture, ni trace"

        journal.clear
        @audit.events.clear
        @classrooms.refusal = Shared::Result.failure(:conflict, errors: { suffix: [ :taken ] })
        update("cls-1")
        assert_equal %i[begin write commit], journal
        assert_empty @audit.events
      end

      test "le préfixe vient du niveau et de la série de la classe : une Tle D reste une Tle D" do
        result = update("cls-2", suffix: "  C   3 ", max_students: "60", actor: direction(of: 5))

        assert result.success?
        assert_equal [ "Tle D C 3", 60 ], [ result.value.name, result.value.max_students ]
      end

      test "un nom libre d'avant l'ADR-0098 est ramené au préfixe du barème" do
        assert_equal "6ème A", update("cls-6").value.name
      end

      test "la direction modifie dans son établissement actif ; ni ailleurs, ni dans un établissement inactif" do
        assert update("cls-1", actor: direction(of: 5)).success?
        assert_equal :forbidden, update("cls-4", actor: direction(of: 5), school_public_id: "autre").code
        assert_equal :forbidden, update("cls-1", actor: direction(of: 6), school_public_id: "ferme").code
        assert_equal 1, @classrooms.writes.size
      end

      test "l'enseignant et l'élève ne modifient aucune classe" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :teacher), Entities::Identity::Actor.new(user_id: 9, role: :student) ].each do |actor|
          assert_equal :forbidden, update("cls-1", actor:).code
        end
        assert_empty @classrooms.writes
      end

      test "établissement inconnu, classe d'un autre établissement, d'une année passée ou inconnue : introuvable" do
        assert_equal :not_found, update("cls-1", school_public_id: "inconnu").code
        assert_equal :not_found, update("cls-4").code
        assert_equal :not_found, update("cls-4", actor: direction(of: 5)).code
        assert_equal :not_found, update("cls-5").code
        assert_equal :not_found, update("cls-404").code
        assert_empty @classrooms.writes
      end

      test "une classe archivée ne se modifie pas : on la restaure d'abord" do
        result = update("cls-3")

        assert_equal [ :conflict, { base: [ :archived ] } ], [ result.code, result.errors ]
        assert_empty @classrooms.writes
      end

      test "suffixe vide, plafond hors de 1 à 150 : invalide, sans écriture" do
        blank = update("cls-1", suffix: "  ")
        blank_input = Input.new(suffix: "  ", max_students: "95").tap(&:valid?)
        assert_equal [ :invalid, [ :suffix ] ], [ blank.code, blank.errors.keys ]
        assert_equal blank_input.errors.map(&:message), blank.errors[:suffix]
        assert blank_input.errors.of_kind?(:suffix, :blank)

        [ "151", "0" ].each do |max_students|
          out_of_range = update("cls-1", max_students:)
          assert_equal [ :invalid, [ :max_students ] ], [ out_of_range.code, out_of_range.errors.keys ], max_students
          assert Input.new(suffix: "A", max_students:).tap(&:valid?).errors.of_kind?(:max_students, :in), max_students
        end
        assert_empty @classrooms.writes
      end

      test "le nom complet tient en 15 caractères : la place du suffixe dépend du préfixe" do
        assert update("cls-2", suffix: "Excellenc").success? # « Tle D Excellenc », 15
        result = update("cls-2", suffix: "Excellence") # 16

        assert_equal [ :invalid, { suffix: [ :too_long ] } ], [ result.code, result.errors ]
        assert_equal 1, @classrooms.writes.size
      end

      test "enregistrer sans rien changer réussit, sans écriture ni trace" do
        result = update("cls-1", suffix: " 3 ", max_students: "80")

        assert result.success?
        assert_equal "6ème 3", result.value.name
        assert_empty @classrooms.writes
        assert_empty @audit.events
      end

      test "un refus du repository (plafond sous l'effectif, nom pris) ressort tel quel, sans trace" do
        [ Shared::Result.failure(:conflict, errors: { max_students: [ :below_headcount ], headcount: 42 }),
          Shared::Result.failure(:conflict, errors: { suffix: [ :taken ] }) ].each do |refusal|
          @classrooms.refusal = refusal

          assert_equal refusal, update("cls-1")
        end
        assert_empty @audit.events
      end
    end
  end
end
