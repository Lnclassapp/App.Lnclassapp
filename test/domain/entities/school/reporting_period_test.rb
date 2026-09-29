require "test_helper"

# ADR-0062 : la période du pilotage, en jours entiers jusqu'à aujourd'hui inclus ; l'année scolaire part du 1er septembre.
module Entities
  module School
    class ReportingPeriodTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 9, 28)

      test "7 jours, 30 jours et l'année scolaire, aujourd'hui compris" do
        assert_equal Date.new(2026, 9, 22), ReportingPeriod.parse("7d", today: TODAY).since
        assert_equal Date.new(2026, 8, 30), ReportingPeriod.parse("30d", today: TODAY).since
        assert_equal Date.new(2026, 9, 1), ReportingPeriod.parse("year", today: TODAY).since
      end

      test "l'année scolaire commencée l'an dernier, avant septembre" do
        assert_equal Date.new(2025, 9, 1), ReportingPeriod.parse("year", today: Date.new(2026, 8, 31)).since
      end

      test "une clé absente ou inconnue vaut 7 jours" do
        [ nil, "", "365d", [ "7d" ] ].each do |key|
          period = ReportingPeriod.parse(key, today: TODAY)

          assert_equal "7d", period.key
          assert_equal Date.new(2026, 9, 22), period.since
        end
      end

      test "les clés, dans l'ordre de l'écran, et la clé par défaut" do
        assert_equal %w[7d 30d year], ReportingPeriod::KEYS
        assert_equal "7d", ReportingPeriod::DEFAULT
        assert ReportingPeriod.parse("30d", today: TODAY).then { it.key == "30d" && !it.default? }
        assert ReportingPeriod.parse(nil, today: TODAY).default?
      end
    end
  end
end
