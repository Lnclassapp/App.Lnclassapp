require "test_helper"

# CA-28 (ADR-XXXX modèles de langage, « Données envoyées ») : ce que l'assistant envoie au modèle pour le brouillon de relance WhatsApp,
# l'empreinte de ces entrées et la mise en forme de la réponse (600 caractères au plus, texte seul).
module Entities
  module Crm
    class WhatsappDraftPromptTest < ActiveSupport::TestCase
      def prompt(**overrides)
        WhatsappDraftPrompt.new(
          school_id: 7, follow_up_id: 9, follow_up_public_id: "follow-pub", school_name: "Lycée Classique d'Abidjan", drena_name: "Abidjan 1",
          reason: "Rappeler pour le devis", due_on: Date.new(2026, 11, 6),
          interactions: [ { occurred_on: Date.new(2026, 10, 30), kind: "call", outcome: "positive", next_step: "Envoyer le devis", note: "Directrice intéressée" } ],
          **overrides
        )
      end

      test "messages are a system instruction then the facts, in French, asking for 600 characters at most" do
        messages = prompt.messages

        assert_equal %w[system user], messages.map { it[:role] }
        facts = messages.last[:content]
        [ "Lycée Classique d'Abidjan", "Abidjan 1", "Rappeler pour le devis", "2026-11-06", "Envoyer le devis", "Directrice intéressée" ].each do |fact|
          assert_includes facts, fact
        end
        assert_match(/600 caractères/, messages.first[:content])
      end

      test "no phone number is sent" do
        assert_no_match(/0[157][0-9]{8}/, prompt.messages.last[:content])
      end

      test "the fingerprint is a SHA-256, equal for equal inputs and different when a fact or the follow-up changes" do
        assert_match(/\A\h{64}\z/, prompt.fingerprint)
        assert_equal prompt.fingerprint, prompt.fingerprint
        assert_not_equal prompt.fingerprint, prompt(reason: "Autre").fingerprint
        assert_not_equal prompt.fingerprint, prompt(follow_up_public_id: "other").fingerprint
        assert_not_equal prompt.fingerprint, prompt(due_on: Date.new(2026, 11, 7)).fingerprint
      end

      test "compose keeps a short message as plain text, without tags" do
        assert_equal "Bonjour, nous avons parlé du devis.", WhatsappDraftPrompt.compose("  <b>Bonjour</b>, nous avons parlé du devis.  ")
      end

      test "compose keeps line breaks but not runs of blank lines" do
        assert_equal "Bonjour,\n\nMerci de votre temps.", WhatsappDraftPrompt.compose("Bonjour,\n\n\n\nMerci de votre temps.")
      end

      test "compose cuts a message above 600 characters at a word boundary" do
        long = ("mot " * 400).strip

        composed = WhatsappDraftPrompt.compose(long)

        assert_operator composed.length, :<=, 600
        assert_operator composed.length, :>, 500
        assert composed.end_with?("mot")
      end

      test "compose cuts a message with no space at 600 characters" do
        assert_equal 600, WhatsappDraftPrompt.compose("a" * 900).length
      end

      test "compose returns nil for an empty answer" do
        assert_nil WhatsappDraftPrompt.compose("  \n ")
        assert_nil WhatsappDraftPrompt.compose(nil)
      end
    end
  end
end
