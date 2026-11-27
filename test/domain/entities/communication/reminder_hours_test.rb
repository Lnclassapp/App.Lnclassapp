require "test_helper"

# ADR-0147, amendement du 2026-11-27 (II) : les rappels partent de 6 h à 21 h, heure d'Abidjan (UTC+0), tous les jours.
module Entities
  module Communication
    class ReminderHoursTest < ActiveSupport::TestCase
      SUNDAY = Time.utc(2026, 11, 29)

      test "ouvert de 6 h à 21 h, fermé la nuit, le dimanche comme en semaine" do
        { [ 5, 59 ] => false, [ 6, 0 ] => true, [ 12, 0 ] => true, [ 20, 59 ] => true, [ 21, 0 ] => false, [ 2, 0 ] => false }.each do |(hour, minute), open|
          assert_equal open, ReminderHours.open?(SUNDAY + hour.hours + minute.minutes), "#{hour} h #{minute}"
        end
      end

      test "un instant d'un autre fuseau est lu à l'heure d'Abidjan" do
        assert ReminderHours.open?(Time.new(2026, 11, 29, 7, 0, 0, "+01:00")) # 6 h à Abidjan
        assert_not ReminderHours.open?(Time.new(2026, 11, 29, 6, 59, 0, "+01:00")) # 5 h 59
      end
    end
  end
end
