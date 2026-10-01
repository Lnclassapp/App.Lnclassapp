require "test_helper"

module Entities
  module Catalog
    # UDR-0013, amendement du 2026-10-01 : un élève lit les cours du niveau de ses classes ; un cours sans série vaut pour
    # toutes les séries du niveau.
    class LevelAudienceTest < ActiveSupport::TestCase
      TLE = 7
      SECONDE = 5
      D = 40
      C = 41

      test "un élève de Tle D lit les cours de Tle D et ceux de Tle sans série, jamais Tle C ni un autre niveau" do
        audience = LevelAudience.new(pairs: [ [ TLE, D ] ])

        assert audience.covers?(level_id: TLE, series_id: D)
        assert audience.covers?(level_id: TLE, series_id: nil)
        assert_not audience.covers?(level_id: TLE, series_id: C)
        assert_not audience.covers?(level_id: SECONDE, series_id: nil)
      end

      test "une classe sans série ne lit que les cours sans série de son niveau ; deux classes, l'union des deux" do
        assert_not LevelAudience.new(pairs: [ [ SECONDE, nil ] ]).covers?(level_id: SECONDE, series_id: D)

        audience = LevelAudience.new(pairs: [ [ SECONDE, nil ], [ TLE, D ], [ TLE, D ] ])

        assert audience.covers?(level_id: SECONDE, series_id: nil)
        assert audience.covers?(level_id: TLE, series_id: D)
        assert_equal [ [ SECONDE, nil ], [ TLE, D ] ], audience.pairs
        assert audience.pairs.frozen?
      end

      test "sans classe, l'élève ne lit rien" do
        assert LevelAudience.none.empty?
        assert_not LevelAudience.none.covers?(level_id: TLE, series_id: nil)
        assert_not LevelAudience.new(pairs: [ [ TLE, D ] ]).empty?
      end
    end
  end
end
