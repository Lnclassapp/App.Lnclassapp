# 🔌 INFRA · Repositories::Assessment::OfflinePackSigner
# Rôle : chiffre, signe et vérifie le jeton d'un paquet de corrigé (MessageEncryptor : aucun identifiant interne lisible, ADR-0029 ; but « offline_pack », 30 jours)
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
        key = Rails.application.key_generator.generate_key(PURPOSE, ActiveSupport::MessageEncryptor.key_len)
        ActiveSupport::MessageEncryptor.new(key, serializer: JSON)
      end

      def sign(student_id:, exercise_id:, digest:, issued_at:)
        @verifier.encrypt_and_sign({ "student_id" => student_id, "exercise_id" => exercise_id, "digest" => digest, "issued_at" => issued_at.utc.iso8601 },
                           purpose: PURPOSE, expires_in: LIFETIME)
      end

      def verify(token)
        return nil unless token.is_a?(String) && token.present?

        payload = @verifier.decrypt_and_verify(token, purpose: PURPOSE)
        return nil unless payload.is_a?(Hash) && FIELDS.all? { payload.key?(it) }

        { student_id: payload["student_id"], exercise_id: payload["exercise_id"], digest: payload["digest"], issued_at: Time.iso8601(payload["issued_at"]).utc }
      rescue ArgumentError, TypeError, ActiveSupport::MessageEncryptor::InvalidMessage
        nil
      end
    end
  end
end
