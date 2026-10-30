require "test_helper"
require "open3"

# ADR-XXXX-figures-des-matieres-de-3eme §4.2 : listes fermées des aires et des lieux de chaque fond de carte.
module Entities
  module Catalog
    class FigureCatalogsTest < ActiveSupport::TestCase
      test "trois fonds : Côte d'Ivoire, Afrique, monde" do
        assert_equal %w[africa cote_d_ivoire world], FigureCatalogs::MAP_BASES.keys.sort
        assert_equal FigureKinds.fetch("map").params["base"].values.sort, FigureCatalogs::MAP_BASES.keys.sort
      end

      test "la Côte d'Ivoire : 14 districts et 4 zones naturelles" do
        districts = FigureCatalogs.areas("cote_d_ivoire") - %w[dense_forest savanna coastal_strip mountain_west]

        assert_equal 14, districts.size
        assert_equal 18, FigureCatalogs.areas("cote_d_ivoire").size
        assert_includes FigureCatalogs.places("cote_d_ivoire"), "kossou"
      end

      test "l'Afrique : 54 États et 54 capitales" do
        assert_equal 54, FigureCatalogs.areas("africa").size
        capitals = FigureCatalogs.places("africa") - %w[abidjan lagos johannesburg casablanca alexandria mombasa douala suez]

        assert_equal 54, capitals.size
      end

      test "le monde : 174 pays et 6 continents, sans Antarctique" do
        continents = %w[africa asia europe north_america south_america oceania]
        countries = FigureCatalogs.areas("world") - continents

        assert_equal 174, countries.size
        assert_empty countries & %w[ata cyn sol]
        assert_equal 6, (FigureCatalogs.areas("world") & continents).size
      end

      test "aucun identifiant n'est répété, tous sont figés" do
        FigureCatalogs::MAP_BASES.each_value do |lists|
          lists.each_value do |ids|
            assert_equal ids.uniq, ids
            assert_predicate ids, :frozen?
          end
        end
      end

      # script/contenus/valider.rb ne charge que figure_kinds et figure : figure.rb doit amener ses catalogues (hors Zeitwerk).
      test "figure.rb charge lui-même ses catalogues quand seul le domaine est chargé" do
        domain = Rails.root.join("app/domain/entities/catalog")
        code = %(require "#{domain.join("figure_kinds")}"; require "#{domain.join("figure")}"; abort("FigureCatalogs absent") unless defined?(Entities::Catalog::FigureCatalogs); ) +
               %(p Entities::Catalog::Figure.errors_for("key" => "carte", "kind" => "map", "description" => "a" * 150, "params" => { "base" => "world", "places" => [ { "id" => "paris" } ] }))
        output, status = Open3.capture2e(RbConfig.ruby, "-e", code)

        assert_predicate status, :success?, output
        assert_equal "[]", output.strip
      end

      test "un fond inconnu n'a ni aire ni lieu" do
        assert_empty FigureCatalogs.areas("moon")
        assert_empty FigureCatalogs.places(nil)
      end
    end
  end
end
