require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"

module Entities
  module Catalog
    class TaxonomyLookupTest < ActiveSupport::TestCase
      setup { @lookup = TaxonomyFixture.lookup }

      test "retrouve niveaux et séries par slug" do
        assert_equal "Tle", @lookup.level("tle").name
        assert_equal "A1", @lookup.find_series("a1").name
        assert_nil @lookup.level("terminale")
        assert_nil @lookup.find_series("b")
      end

      test "résout un nom saisi après parameterize, par slug ou par nom" do
        assert_equal "tle", @lookup.resolve_level("TLE").slug
        assert_equal "1ere", @lookup.resolve_level("1ère").slug
        assert_equal "d", @lookup.resolve_series(" D ").slug
        assert_nil @lookup.resolve_level(nil)
      end

      test "résout une matière par son nom, son slug ou son abrégé" do
        assert_equal 201, @lookup.resolve_material("Physique Chimie").id
        assert_equal 201, @lookup.resolve_material("pc").id
        assert_nil @lookup.resolve_material("Chimie")
      end

      test "connaît les couples niveau–série" do
        tle = @lookup.level("tle")

        assert @lookup.pair?(tle.id, @lookup.find_series("d").id)
        assert_not @lookup.pair?(tle.id, @lookup.find_series("a").id)
        assert_equal %w[a1 a2 c d], @lookup.series_for(tle.id).map(&:slug)
        assert_equal %w[a c], @lookup.series_for(@lookup.level("2nde").id).map(&:slug)
        assert_empty @lookup.series_for(@lookup.level("3eme").id)
      end

      test "un slug n'est jamais masqué par le nom d'un autre élément" do
        lookup = TaxonomyLookup.new(levels: [ Level.new(id: 1, slug: "a", name: "B"), Level.new(id: 2, slug: "b", name: "A"),
                                                Level.new(id: 3, slug: "c", name: nil) ],
                                    series: [], materials: [], pairs: [])

        assert_equal 1, lookup.resolve_level("a").id
        assert_equal 2, lookup.resolve_level("b").id
        assert_equal 3, lookup.resolve_level("c").id
      end
    end
  end
end
