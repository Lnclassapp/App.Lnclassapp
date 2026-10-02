require "test_helper"

module Entities
  module Classroom
    # ADR-0072 §4.2, §7 : l'échéance est le prochain jour de séance strictement après la date d'assignation.
    class SessionDaysTest < ActiveSupport::TestCase
      MONDAY = Date.new(2026, 10, 5)

      def days(*weekdays) = SessionDays.new(weekdays:)

      test "lundi et jeudi : assigné lundi → jeudi ; jeudi → lundi suivant ; dimanche → lundi" do
        monday_thursday = days(1, 4)

        assert_equal Date.new(2026, 10, 8), monday_thursday.next_after(MONDAY)
        assert_equal Date.new(2026, 10, 12), monday_thursday.next_after(Date.new(2026, 10, 8))
        assert_equal Date.new(2026, 10, 12), monday_thursday.next_after(Date.new(2026, 10, 11))
        assert_equal Date.new(2026, 10, 8), monday_thursday.next_after(Date.new(2026, 10, 6))
      end

      test "un seul jour (mercredi), assigné mercredi → mercredi + 7, jamais le jour même" do
        wednesday = Date.new(2026, 10, 7)

        assert_equal wednesday + 7, days(3).next_after(wednesday)
      end

      test "sans jours, pas d'échéance" do
        assert_nil days.next_after(MONDAY)
        assert days.none?
        assert_not days(6).none?
      end

      test "les jours sont triés, dédoublonnés, lus depuis des chaînes, et figés" do
        session_days = days("4", 1, 4)

        assert_equal [ 1, 4 ], session_days.weekdays
        assert session_days.weekdays.frozen?
        assert_equal days(1, 4), session_days
        assert_equal [], SessionDays.new(weekdays: nil).weekdays
      end

      test "le dimanche (7), le jour 0 ou une valeur illisible lèvent ArgumentError" do
        [ [ 7 ], [ 0 ], [ 1, 7 ], [ "lundi" ] ].each do |weekdays|
          assert_raises(ArgumentError, weekdays.inspect) { SessionDays.new(weekdays:) }
        end
        assert_equal 1..6, SessionDays::WEEKDAYS
      end
    end
  end
end
