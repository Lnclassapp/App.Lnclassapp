require "test_helper"

module Entities
  module Billing
    class CommissionWeekTest < ActiveSupport::TestCase
      test "la semaine va du vendredi 00:00 au jeudi 23:59" do
        week = CommissionWeek.containing(Time.utc(2026, 11, 12, 23, 59, 59))

        assert_equal [ Date.new(2026, 11, 6), Date.new(2026, 11, 12) ], [ week.starts_on, week.ends_on ]
        assert week.cover?(Time.utc(2026, 11, 6, 0, 0, 0))
        assert week.cover?(Time.utc(2026, 11, 12, 23, 59, 59))
        assert_not week.cover?(Time.utc(2026, 11, 13, 0, 0, 0))
        assert_not week.cover?(Time.utc(2026, 11, 5, 23, 59, 59))
      end

      test "le vendredi ouvre une nouvelle semaine, la précédente est celle qui vient de finir" do
        friday = Time.utc(2026, 11, 13, 8)

        assert_equal Date.new(2026, 11, 13), CommissionWeek.containing(friday).starts_on
        assert_equal Date.new(2026, 11, 6), CommissionWeek.previous(at: friday).starts_on
        assert_equal Date.new(2026, 10, 30), CommissionWeek.previous(at: Time.utc(2026, 11, 12, 20)).starts_on
      end

      test "les dernières semaines écoulées, de la plus récente à la plus ancienne" do
        weeks = CommissionWeek.recent(3, at: Time.utc(2026, 11, 13))

        assert_equal [ Date.new(2026, 11, 6), Date.new(2026, 10, 30), Date.new(2026, 10, 23) ], weeks.map(&:starts_on)
      end

      test "la commission est de 200 F par activation payante" do
        week = CommissionWeek.containing(Time.utc(2026, 11, 7))

        assert_equal 400, week.commission_xof(2)
        assert_equal 0, week.commission_xof(0)
      end

      test "les bornes en temps sont en UTC, la fin est exclue" do
        week = CommissionWeek.containing(Time.utc(2026, 11, 7))

        assert_equal Time.utc(2026, 11, 6), week.starts_at
        assert_equal Time.utc(2026, 11, 13), week.ends_at
      end
    end
  end
end
