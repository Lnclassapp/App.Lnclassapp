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

      test "5 et 9 échecs verrouillent 15 minutes" do
        assert_equal 15.minutes, retry_after(5)
        assert_equal 5.minutes, retry_after(9, ago: 10.minutes)
        assert_nil retry_after(9, ago: 15.minutes)
      end

      test "10 et 19 échecs verrouillent 1 heure" do
        assert_equal 1.hour, retry_after(10)
        assert_equal 1.hour, retry_after(19)
        assert_nil retry_after(19, ago: 2.hours)
      end

      test "20 échecs verrouillent jusqu'à la récupération assistée" do
        assert_equal :until_recovery, retry_after(20, ago: 30.days)
        assert_equal :until_recovery, retry_after(25)
      end

      test "arrondit le temps restant à la seconde supérieure" do
        assert_equal 1.second, Lockout.retry_after(failures: 5, last_failed_at: NOW - 15.minutes + 0.2, now: NOW)
      end

      test "signale le franchissement exact d'un palier" do
        assert Lockout.tier_reached?(5)
        assert Lockout.tier_reached?(10)
        assert Lockout.tier_reached?(20)
        assert_not Lockout.tier_reached?(6)
      end
    end
  end
end
