require "test_helper"

# CA-27 (ADR-XXXX modèles de langage, schéma fermé) : une réponse conforme pré-remplit le formulaire ; toute autre réponse
# (texte libre, JSON hors schéma, valeur hors liste, trop longue) retombe sur la seule transcription dans la note.
module Entities
  module Crm
    class DictationDraftTest < ActiveSupport::TestCase
      def answer(**overrides)
        { kind: "call", outcome: "positive", contact_name: "Mme Kouassi", next_step: "Envoyer la plaquette", note: "Directrice intéressée.",
          follow_up_in_days: 3 }.merge(overrides)
      end

      test "a conforming answer is structured" do
        draft = DictationDraft.parse(answer.to_json)

        assert draft.structured
        assert_equal "call", draft.kind
        assert_equal "positive", draft.outcome
        assert_equal "Mme Kouassi", draft.contact_name
        assert_equal "Envoyer la plaquette", draft.next_step
        assert_equal "Directrice intéressée.", draft.note
        assert_equal 3, draft.follow_up_in_days
      end

      test "a fenced JSON answer is read" do
        assert DictationDraft.parse("```json\n#{answer.to_json}\n```").structured
      end

      test "optional fields may be null" do
        draft = DictationDraft.parse(answer(contact_name: nil, next_step: nil, follow_up_in_days: nil).to_json)

        assert draft.structured
        assert_nil draft.follow_up_in_days
      end

      test "CA-27: free text falls back to the raw transcription in the note" do
        draft = DictationDraft.parse("J'ai appelé la directrice, elle veut une démo la semaine prochaine.")

        assert_not draft.structured
        assert_equal "J'ai appelé la directrice, elle veut une démo la semaine prochaine.", draft.note
        assert_nil draft.kind
        assert_nil draft.outcome
        assert_nil draft.follow_up_in_days
      end

      test "the schema is closed: an unknown key, a value out of its list or out of range falls back" do
        [ answer(extra: "x"), answer(kind: "email"), answer(outcome: "great"), answer(follow_up_in_days: 0), answer(follow_up_in_days: 400),
          answer(follow_up_in_days: "3"), answer(note: 12), answer(note: "x" * 2001), answer(next_step: "x" * 201),
          answer(contact_name: "x" * 81), answer(kind: nil) ].each do |bad|
          draft = DictationDraft.parse(bad.to_json)
          assert_not draft.structured, "#{bad.inspect} aurait dû être refusé"
          assert_nil draft.kind
        end
      end

      test "a JSON array or scalar falls back" do
        assert_not DictationDraft.parse("[1,2]").structured
        assert_not DictationDraft.parse("42").structured
      end

      test "the fallback note is the raw text, tags removed and cut to the note length" do
        draft = DictationDraft.parse("<b>Bonjour</b> <script>alert(1)</script>#{'a' * 3000}")

        assert_not_includes draft.note, "<"
        assert_includes draft.note, "Bonjour"
        assert_operator draft.note.length, :<=, Interaction::NOTE_MAX
      end

      test "an out-of-schema JSON answer gives its text field as the transcription, else the raw text" do
        assert_equal "Texte dicté", DictationDraft.parse({ transcription: "Texte dicté", foo: 1 }.to_json).note
        assert_includes DictationDraft.parse({ foo: 1 }.to_json).note, "foo"
      end

      test "the stored content round-trips, structured or not" do
        structured = DictationDraft.parse(answer.to_json)
        assert_equal structured, DictationDraft.from_content(structured.to_content)

        fallback = DictationDraft.parse("texte libre")
        assert_equal fallback, DictationDraft.from_content(fallback.to_content)
        assert_not DictationDraft.from_content("n'importe quoi").structured
        assert_not DictationDraft.from_content(nil).structured
      end

      test "the prompt asks for the closed schema and gives today's date, without any identity" do
        messages = DictationPrompt.messages(today: Date.new(2026, 11, 5))

        assert_equal %w[system user], messages.map { it[:role] }
        assert_includes messages.last[:content], "2026-11-05"
        DictationDraft::KEYS.each { assert_includes messages.first[:content], it }
        assert messages.all? { it[:content].is_a?(String) }
      end
    end
  end
end
