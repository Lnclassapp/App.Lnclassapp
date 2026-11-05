require "test_helper"

# CA-22 (ADR-XXXX modèles de langage, « Données envoyées ») : ce que l'assistant de briefing envoie au modèle, l'empreinte de ces
# entrées (qui commande la réutilisation) et la mise en forme de la réponse en 5 lignes au plus.
module Entities
  module Crm
    class BriefingPromptTest < ActiveSupport::TestCase
      def prompt(**overrides)
        BriefingPrompt.new(
          school_id: 7, school_name: "Lycée Classique d'Abidjan", drena_name: "Abidjan 1", stage: "demo_done", accounts_count: 3,
          active_students_count: 12, last_activity_on: Date.new(2026, 11, 2), contact_positions: %w[director censor],
          interactions: [ { occurred_on: Date.new(2026, 10, 30), kind: "call", outcome: "positive", next_step: "Envoyer le devis", note: "Directrice intéressée" } ],
          follow_ups: [ { due_on: Date.new(2026, 11, 6), reason: "Rappeler pour le devis" } ], **overrides
        )
      end

      test "messages are a system instruction then the facts of the school, in French" do
        messages = prompt.messages

        assert_equal %w[system user], messages.map { it[:role] }
        facts = messages.last[:content]
        [ "Lycée Classique d'Abidjan", "Abidjan 1", "Démo faite", "Envoyer le devis", "Directrice intéressée", "Rappeler pour le devis" ].each do |fact|
          assert_includes facts, fact
        end
        assert_match(/5 lignes/, messages.first[:content])
      end

      test "no contact name or phone is sent, only positions" do
        facts = prompt.messages.last[:content]

        assert_includes facts, "directeur"
        assert_no_match(/0[157][0-9]{8}/, facts)
      end

      test "the fingerprint is a SHA-256, equal for equal inputs and different when one fact changes" do
        assert_match(/\A\h{64}\z/, prompt.fingerprint)
        assert_equal prompt.fingerprint, prompt.fingerprint
        assert_not_equal prompt.fingerprint, prompt(active_students_count: 13).fingerprint
        changed = prompt(interactions: [ prompt.interactions.first.merge(note: "Autre note") ])
        assert_not_equal prompt.fingerprint, changed.fingerprint
      end

      test "summarize keeps five lines at most, without bullets, blank lines or HTML" do
        text = "- Un\n\n* Deux\n• Trois\n1. Quatre\n2) Cinq\nSix\n<b>Sept</b>"

        lines = BriefingPrompt.summarize(text).split("\n")

        assert_equal [ "Un", "Deux", "Trois", "Quatre", "Cinq" ], lines
        assert_equal "Sept", BriefingPrompt.summarize("<b>Sept</b>")
      end

      test "summarize caps a line and refuses an empty answer" do
        assert_equal 200, BriefingPrompt.summarize("a" * 500).length
        assert_nil BriefingPrompt.summarize("  \n \n")
        assert_nil BriefingPrompt.summarize(nil)
      end
    end
  end
end
