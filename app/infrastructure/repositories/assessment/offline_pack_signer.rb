# 🔌 INFRA · Repositories::Assessment::OfflinePackSigner
# Rôle : signe et vérifie le jeton d'un paquet de corrigé avec ActiveSupport::MessageVerifier (but « offline_pack », 30 jours)
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4) · menace C3, P4, R4
module Repositories
  module Assessment
    class OfflinePackSigner
      include Ports::Assessment::OfflinePackSignerPort

      PURPOSE = "offline_pack".freeze
      LIFETIME = 30.days
      FIELDS = %w[student_id exercise_id digest issued_at].freeze

      def initialize(verifier: self.class.default_verifier)
        @verifier = verifier
      end

      def self.default_verifier
        ActiveSupport::MessageVerifier.new(Rails.application.key_generator.generate_key(PURPOSE), digest: "SHA256", serializer: JSON)
      end

      def sign(student_id:, exercise_id:, digest:, issued_at:)
        @verifier.generate({ "student_id" => student_id, "exercise_id" => exercise_id, "digest" => digest, "issued_at" => issued_at.utc.iso8601 },
                           purpose: PURPOSE, expires_in: LIFETIME)
      end

      def verify(token)
        return nil unless token.is_a?(String) && token.present?

        payload = @verifier.verified(token, purpose: PURPOSE)
        return nil unless payload.is_a?(Hash) && FIELDS.all? { payload.key?(it) }

        { student_id: payload["student_id"], exercise_id: payload["exercise_id"], digest: payload["digest"], issued_at: Time.iso8601(payload["issued_at"]).utc }
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
