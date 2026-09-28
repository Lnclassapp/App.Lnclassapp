require "test_helper"

module Entities
  module Classroom
    # ADR-0059 : le contrôle du niveau et de la série, partagé par « Ajouter une classe » et « + » du bloc par niveau.
    class PlacementTest < ActiveSupport::TestCase
      School = Data.define(:cycle)

      setup { @lookup = Entities::Catalog::TaxonomyFixture.lookup }

      def resolve(level_slug: "tle", series_slug: "d", cycle: "both")
        Placement.resolve(school: School.new(cycle:), level_slug:, series_slug:, lookup: @lookup)
      end

      test "un couple ouvert donne le niveau et la série" do
        result = resolve

        assert result.success?
        assert_equal [ "Tle", "D" ], [ result.value.level.name, result.value.series.name ]
        assert_equal({ level_id: 7, series_id: 105 }, result.value.ids)
      end

      test "un niveau sans série se place sans série" do
        placement = resolve(level_slug: "6eme", series_slug: nil).value

        assert_nil placement.series
        assert_equal({ level_id: 1, series_id: nil }, placement.ids)
      end

      test "chaque refus nomme son champ" do
        assert_equal({ level_slug: [ :inclusion ] }, resolve(level_slug: "cp").errors)
        assert_equal({ level_slug: [ :not_allowed ] }, resolve(cycle: "first").errors)
        assert_equal({ series_slug: [ :inclusion ] }, resolve(series_slug: "z").errors)
        assert_equal({ series_slug: [ :blank ] }, resolve(series_slug: nil).errors)
        assert_equal({ series_slug: [ :not_allowed ] }, resolve(level_slug: "6eme").errors)
        assert_equal :invalid, resolve(level_slug: "cp").code
      end
    end
  end
end
