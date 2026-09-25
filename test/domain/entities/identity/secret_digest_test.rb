require "test_helper"

module Entities
  module Identity
    class SecretDigestTest < ActiveSupport::TestCase
      test "calcule un HMAC-SHA256 hexadécimal dépendant de la clé" do
        digest = SecretDigest.hmac("12345678", key: "k1")

        assert_match(/\A\h{64}\z/, digest)
        assert_equal digest, SecretDigest.hmac("12345678", key: "k1")
        assert_not_equal digest, SecretDigest.hmac("12345678", key: "k2")
      end

      test "compare à temps constant, et refuse nil" do
        assert SecretDigest.secure_compare("abc", "abc")
        assert_not SecretDigest.secure_compare("abc", "abd")
        assert_not SecretDigest.secure_compare(nil, "abc")
        assert_not SecretDigest.secure_compare("abc", nil)
      end

      test "génère un jeton de session de 32 octets, jamais deux fois le même" do
        token = SecretDigest.generate_token

        assert_equal 32, Base64.urlsafe_decode64(token).bytesize
        assert_not_equal token, SecretDigest.generate_token
      end
    end
  end
end
