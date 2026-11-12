# 🔌 INFRA · Repositories::Assessment::OfflinePackSigner
# Rôle : chiffre, signe et vérifie le jeton d'un paquet de corrigé (MessageEncryptor : aucun identifiant interne lisible, ADR-0029 ; but « offline_pack », 30 jours)
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4) · menace C3, P4, R4
module Repositories
  module Assessment
    class OfflinePackSigner
      include Ports::Assessment::OfflinePackSignerPort

      PURPOSE = "offline_pack".freeze
      LIFETIME = 30.days
      # L'enveloppe du chiffrement vit plus longtemps que le jeton : un jeton périmé se lit encore, ce qui permet de dire « expiré »
      # (et non « altéré ») à l'appareil. La vraie échéance (expires_at, 30 jours après la signature) est jugée ici.
      ENVELOPE_LIFETIME = 365.days
      FIELDS = %w[student_id exercise_id digest issued_at expires_at].freeze

      def initialize(verifier: self.class.default_verifier)
        @verifier = verifier
      end

      def self.default_verifier
        key = Rails.application.key_generator.generate_key(PURPOSE, ActiveSupport::MessageEncryptor.key_len)
        ActiveSupport::MessageEncryptor.new(key, serializer: JSON)
      end

      def sign(student_id:, exercise_id:, digest:, issued_at:)
        @verifier.encrypt_and_sign({ "student_id" => student_id, "exercise_id" => exercise_id, "digest" => digest, "issued_at" => issued_at.utc.iso8601,
                                                 "expires_at" => (Time.current + LIFETIME).utc.iso8601 },
                                               purpose: PURPOSE, expires_in: ENVELOPE_LIFETIME)
      end

      def verify(token:)
        payload = read(token)
        return nil if payload.nil? || expired_payload?(payload)

        { student_id: payload["student_id"], exercise_id: payload["exercise_id"], digest: payload["digest"], issued_at: Time.iso8601(payload["issued_at"]).utc }
      rescue ArgumentError, TypeError
        nil
      end

      # Vrai pour un jeton authentique dont les 30 jours sont passés (verify rend alors nil) ; faux pour un jeton altéré ou valable.
      def expired?(token:)
        payload = read(token)
        !payload.nil? && expired_payload?(payload)
      rescue ArgumentError, TypeError
        false
      end

      private

      def read(token)
        return nil unless token.is_a?(String) && token.present?

        payload = @verifier.decrypt_and_verify(token, purpose: PURPOSE)
        payload if payload.is_a?(Hash) && FIELDS.all? { payload.key?(it) }
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        nil
      end

      def expired_payload?(payload) = Time.iso8601(payload["expires_at"]) <= Time.current
    end
  end
end
