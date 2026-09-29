require "test_helper"

module Entities
  module Identity
    # CP-01, CP-03 (ADR-0063): the referral token travels in a URL; only its shape is checked, never looked up here.
    class ReferralTokenTest < ActiveSupport::TestCase
      test "a token of 12 hexadecimal characters is kept, trimmed and in lower case" do
        assert_equal "0a1b2c3d4e5f", ReferralToken.normalize(" 0A1B2C3D4E5F ")
      end

      test "anything else is dropped: absent, too short, too long, outside the alphabet" do
        [ nil, "", "0a1b2c", "0a1b2c3d4e5f6", "0a1b2c3d4e5g", "usr-41" ].each { assert_nil ReferralToken.normalize(it), it.inspect }
      end
    end

    # CP-04: the closed list of share channels.
    class ShareChannelTest < ActiveSupport::TestCase
      test "whatsapp, sms, copy and native are the only channels" do
        assert_equal %w[whatsapp sms copy native], ShareChannel::ALL
        assert ShareChannel.valid?("sms")
        assert_not ShareChannel.valid?("email")
      end
    end
  end
end
