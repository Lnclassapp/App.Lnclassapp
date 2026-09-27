# 🧠 DOMAINE · Entities::Identity::SecretDigest
# Rôle : empreinte HMAC-SHA256 des secrets (jetons, codes) et comparaison à temps constant
# ADR  : 0031, 0032, 0038, 0050
module Entities
  module Identity
    module SecretDigest
      TOKEN_BYTES = 32

      def self.hmac(value, key:) = OpenSSL::HMAC.hexdigest("SHA256", key, value.to_s)

      def self.secure_compare(left, right)
        return false if left.nil? || right.nil?

        ActiveSupport::SecurityUtils.secure_compare(left, right)
      end

      # Jeton de session : 32 octets aléatoires, encodés pour un cookie.
      def self.generate_token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    end
  end
end
