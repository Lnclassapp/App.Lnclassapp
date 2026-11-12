require "test_helper"

# hors-connexion, Lot 0 (ADR §4.4, menace C3 et P4) : le jeton du paquet lie l'élève, l'exercice, la version et l'heure d'émission.
module Repositories
  module Assessment
    class OfflinePackSignerTest < ActiveSupport::TestCase
      ISSUED = Time.utc(2026, 11, 12, 9, 30, 15)

      setup { @signer = OfflinePackSigner.new }

      def token = @signer.sign(student_id: 7, exercise_id: 42, digest: "abcdef0123456789", issued_at: ISSUED)

      test "un jeton signé se vérifie et rend ses quatre champs" do
        assert_equal({ student_id: 7, exercise_id: 42, digest: "abcdef0123456789", issued_at: ISSUED }, @signer.verify(token))
      end

      test "un jeton modifié, vide ou qui n'est pas un texte rend nil" do
        assert_nil @signer.verify("#{token}x")
        assert_nil @signer.verify("")
        assert_nil @signer.verify(nil)
        assert_nil @signer.verify({ student_id: 7 })
      end

      test "un jeton d'un autre but est refusé" do
        other = ActiveSupport::MessageVerifier.new(Rails.application.key_generator.generate_key("offline_pack"), digest: "SHA256", serializer: JSON)
        foreign = other.generate({ "student_id" => 7 }, purpose: "autre")

        assert_nil @signer.verify(foreign)
      end

      test "un jeton expire après 30 jours" do
        signed = token

        travel_to(ISSUED + 29.days) { assert_not_nil @signer.verify(signed) }
        travel_to(ISSUED + 31.days) { assert_nil @signer.verify(signed) }
      end

      test "un jeton dont la charge est incomplète rend nil" do
        verifier = ActiveSupport::MessageVerifier.new(Rails.application.key_generator.generate_key("offline_pack"), digest: "SHA256", serializer: JSON)
        partial = verifier.generate({ "student_id" => 7 }, purpose: "offline_pack")

        assert_nil @signer.verify(partial)
      end
    end
  end
end
