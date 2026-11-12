require "test_helper"

# hors-connexion, Lot 0 (ADR §4.5, menace R1, R2, R5) : la charge d'une copie hors ligne ne porte que des réponses ;
# toute note envoyée est ignorée, l'identifiant de copie est un UUID v4, les heures sont en ISO 8601.
module Dtos
  module Assessment
    class OfflineCopyInputTest < ActiveSupport::TestCase
      UUID = "3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f5a6b".freeze

      def input(**overrides)
        OfflineCopyInput.new(
          client_copy_id: UUID, exercise_public_id: "ex123", pack_token: "tok", started_at: "2026-11-12T10:00:00.000Z",
          submitted_at: "2026-11-12T10:20:00Z", answers: { "1" => { answer_ids: [ "3" ] } }, **overrides
        )
      end

      test "une charge complète est valide et lit ses heures" do
        copy = input

        assert_predicate copy, :valid?
        assert_equal [ Time.utc(2026, 11, 12, 10), Time.utc(2026, 11, 12, 10, 20) ], [ copy.started_at, copy.submitted_at ]
        assert_equal UUID, copy.client_copy_id
      end

      test "l'identifiant doit être un UUID v4" do
        assert_not_predicate input(client_copy_id: "pas-un-uuid"), :valid?
        assert_not_predicate input(client_copy_id: "3f2b8a1e-5c4d-1e6f-9a7b-1c2d3e4f5a6b"), :valid?
        assert_not_predicate input(client_copy_id: nil), :valid?
      end

      test "une heure illisible est refusée" do
        assert_not_predicate input(started_at: "hier"), :valid?
        assert_not_predicate input(submitted_at: nil), :valid?
        assert_not_predicate input(started_at: 12), :valid?
      end

      test "exercice et jeton sont exigés" do
        assert_not_predicate input(exercise_public_id: ""), :valid?
        assert_not_predicate input(pack_token: nil), :valid?
      end

      test "une note envoyée est ignorée : elle n'entre jamais dans la copie" do
        copy = input(score: 100, provisional_percent: 100, status: "synced")

        assert_predicate copy, :valid?
        assert_not_respond_to copy, :score
        assert_not_respond_to copy, :provisional_percent
      end

      test "to_copy_input rend un CopyInput relié à la session" do
        copy = input.to_copy_input(session_public_id: "sess1")

        assert_instance_of CopyInput, copy
        assert_equal "sess1", copy.session_public_id
        assert_equal [ 3 ], copy.answers[1].answer_ids
      end

      test "des réponses illisibles rendent la charge invalide" do
        assert_not_predicate input(answers: "x"), :valid?
        assert_not_predicate input(answers: (1..101).to_h { [ it.to_s, { response_text: "a" } ] }), :valid?
      end
    end
  end
end
