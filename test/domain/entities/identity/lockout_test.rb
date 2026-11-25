require "test_helper"

module Entities
  module Identity
    class LockoutTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)

      def retry_after(failures, ago: 0.seconds) = Lockout.retry_after(failures:, last_failed_at: NOW - ago, now: NOW)

      test "4 échecs ne verrouillent pas" do
        assert_nil retry_after(4)
        assert_nil retry_after(0)
      end

      test "le 5e échec verrouille jusqu'à la récupération assistée, quel que soit le temps écoulé" do
        assert_equal :until_recovery, retry_after(5)
        assert_equal :until_recovery, retry_after(5, ago: 30.days)
        assert_equal :until_recovery, retry_after(25)
      end

      test "une récupération remet le compteur à zéro : plus d'échec, plus de verrou" do
        assert_nil retry_after(0, ago: 1.minute)
      end

      test "signale le franchissement exact du seul palier" do
        assert Lockout.tier_reached?(5)
        assert_not Lockout.tier_reached?(4)
        assert_not Lockout.tier_reached?(6)
        assert_not Lockout.tier_reached?(10)
      end
    end
  end
end
