require "test_helper"
require "open3"

# ADR-0117 §4.2 : listes fermées des aires et des lieux de chaque fond de carte.
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

      test "onze planches (huit de SVT, trois de PC), leurs parties uniques et figées, et la sorte plate ne propose que celles-là" do
        assert_equal %w[blood_smear digestive_system double_circulation dynamometer electrolyser eudiometer female_reproductive_system heart hiv_virus root_hairs soil_profile], FigureCatalogs::PLATES.keys.sort
        assert_equal FigureCatalogs::PLATES.keys.sort, FigureKinds.fetch("plate").params["plate"].values.sort
        assert_equal [ 11, 6, 12, 8, 7, 7, 6, 9, 7, 9, 7 ], FigureCatalogs::PLATES.values_at(*%w[digestive_system blood_smear heart double_circulation female_reproductive_system hiv_virus soil_profile root_hairs dynamometer electrolyser eudiometer]).map(&:size)
        FigureCatalogs::PLATES.each_value do |parts|
          assert_equal parts.uniq, parts
          assert_predicate parts, :frozen?
        end
      end

      test "les parties des planches de PC, dans l'ordre du dessin" do
        assert_equal %w[ring tube spring scale pointer hook load], FigureCatalogs.parts("dynamometer")
        assert_equal %w[generator vessel electrolyte anode cathode oxygen_tube hydrogen_tube oxygen hydrogen], FigureCatalogs.parts("electrolyser")
        assert_equal %w[tube scale electrodes spark gas_mixture water trough], FigureCatalogs.parts("eudiometer")
      end

      test "les parties d'une planche, vides pour une planche inconnue" do
        assert_equal %w[ovary oviduct infundibulum uterus endometrium cervix vagina], FigureCatalogs.parts("female_reproductive_system")
        assert_empty FigureCatalogs.parts("skeleton")
        assert_empty FigureCatalogs.parts(nil)
      end

      test "un fond inconnu n'a ni aire ni lieu" do
        assert_empty FigureCatalogs.areas("moon")
        assert_empty FigureCatalogs.places(nil)
      end
    end
  end
end
