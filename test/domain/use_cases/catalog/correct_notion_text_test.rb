require "test_helper"

# edition-lecon-equipe, Lot B (ADR-0113 §4.6, amendement du 2026-11-14) : l'équipe corrige à l'écran le texte d'une notion, même
# publiée et déjà travaillée ; la structure (nombre d'étapes, entraînement, figure) reste à l'import.
module UseCases
  module Catalog
    class CorrectNotionTextTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 14, 12)
      Clock = Data.define(:now)
      Essential = Entities::Catalog::Essential
      Text = CorrectNotionText::NotionText

      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        attr_reader :written, :locked

        def initialize(essentials, sheets)
          @stored = essentials
          @sheets = sheets
          @written = []
          @locked = []
        end

        def find_by_slug(slug:) = @stored.find { it.slug == slug }
        def lock(id:) = (@locked << id) && true
        def sheet_of(id:) = @sheets.fetch(id)
        def ids_by_name(course_id:) = @stored.select { it.course_id == course_id }.to_h { [ Entities::Shared::NaturalKey.normalize(it.name), it.id ] }

        def correct_text(id:, name:, sheet:, at:)
          raise FakeTransaction::Refused if name == "Collision"

          @written << { id:, name:, sheet:, at: }
          @stored.find { it.id == id }.name = name
          true
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :records

        def initialize = @records = []
        def record(**entry) = (@records << entry) && true
      end

      SHEET = {
        "remember" => "Retiens.", "method" => [ "Étape 1", "Étape 2" ],
        "example" => { "statement" => "Énoncé", "steps" => [ "Pas 1", "Pas 2" ] }, "pitfall" => "Piège.",
        "figure" => "thales", "practice" => { "kept" => true }
      }.freeze

      setup do
        @essentials = FakeEssentials.new(
          [ Essential.new(id: 10, slug: "thales", course_id: 1, name: "Thalès", status: "published", course_status: "published"),
            Essential.new(id: 11, slug: "pythagore", course_id: 1, name: "Pythagore", status: "published", course_status: "published") ],
          { 10 => SHEET, 11 => SHEET }
        )
        @audit_log = FakeAuditLog.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def text(**overrides)
        Text.new(name: "Thalès corrigé", remember: "Retiens bien.", method_steps: [ "Étape un", "Étape deux" ],
                 example_statement: "Énoncé corrigé", example_steps: [ "Pas un", "Pas deux" ], pitfall: "Piège corrigé.", **overrides)
      end

      def correct(slug = "thales", actor: @team, **overrides)
        CorrectNotionText.new(essentials: @essentials, audit_log: @audit_log, transaction: FakeTransaction.new,
                              policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                         .call(actor:, slug:, text: text(**overrides))
      end

      test "the team corrects the text of a published notion; the practice, the figure and unknown keys are kept; the journal says so" do
        result = correct

        assert result.success?
        written = @essentials.written.sole
        assert_equal "Thalès corrigé", written[:name]
        assert_equal({ "remember" => "Retiens bien.", "method" => [ "Étape un", "Étape deux" ],
                       "example" => { "statement" => "Énoncé corrigé", "steps" => [ "Pas un", "Pas deux" ] },
                       "pitfall" => "Piège corrigé.", "figure" => "thales", "practice" => { "kept" => true } }, written[:sheet])
        assert_equal [ 10 ], @essentials.locked
        assert_equal({ action: "content.corrected", actor_id: 7, at: NOW, subject_type: "Essential", subject_id: 10,
                       metadata: { slug: "thales" } }, @audit_log.records.sole)
      end

      test "a non-team actor is refused, nothing written" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher)

        assert_equal :forbidden, correct(actor: teacher).code
        assert_empty @essentials.written
      end

      test "an unknown notion is not found" do
        assert_equal :not_found, correct("inconnue").code
      end

      test "adding or removing a step of the method or of the example is refused: the structure stays with the import" do
        [ { method_steps: [ "Un", "Deux", "Trois" ] }, { example_steps: [ "Un" ] } ].each do |change|
          result = correct(**change)

          assert_equal :invalid, result.code
          assert_equal [ :structure_changed ], result.errors[:base]
        end
        assert_empty @essentials.written
      end

      test "a blank or too long text is refused with its field; a name taken by another notion of the lesson too" do
        assert_equal [ :blank ], correct(remember: "  ").errors[:remember]
        assert_equal [ :too_long ], correct(pitfall: "x" * 1_201).errors[:pitfall]
        assert_equal [ :blank ], correct(method_steps: [ "Un", "" ]).errors[:"method[1]"]
        assert_equal [ :blank ], correct(name: " ").errors[:name]
        assert_equal [ :taken ], correct(name: "pythagore").errors[:name]
        assert_empty @essentials.written
      end

      # Revue pannes silencieuses : aucune erreur sans message, aucun 500 sur une collision de noms.
      test "a sheet already out of bounds at import is refused at the top of the modal: reimport" do
        @essentials = FakeEssentials.new([ Essential.new(id: 10, slug: "thales", course_id: 1, name: "Thalès", status: "published",
                                                         course_status: "published") ],
                                         { 10 => SHEET.merge("method" => [ "Seule étape" ]) })

        result = correct(method_steps: [ "Seule étape corrigée" ])

        assert_equal :invalid, result.code
        assert_equal [ :reimport ], result.errors[:base]
        assert_empty @essentials.written
      end

      test "two renames to the same name at once: the unique index refuses the second, which reads « name taken »" do
        result = correct(name: "Collision")

        assert_equal :invalid, result.code
        assert_equal [ :taken ], result.errors[:name]
      end
    end
  end
end
