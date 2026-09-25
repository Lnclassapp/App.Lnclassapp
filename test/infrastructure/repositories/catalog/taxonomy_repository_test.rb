require "test_helper"

module Repositories
  module Catalog
    class TaxonomyRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = TaxonomyRepository.new
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def level(name: "Tle", position: 7, cycle: "second") = Entities::Catalog::Level.new(name:, position:, cycle:)

      def material(name: "SVT", shortname: "SVT", category: "science")
        Entities::Catalog::Material.new(name:, shortname:, category:)
      end

      test "liste niveaux par position, séries et matières par nom, en entités" do
        seed_referential

        assert_equal [ "6ème", "5ème", "4ème", "3ème", "2nde", "1ère", "Tle" ], @repository.levels.map(&:name)
        assert_equal %w[A A1 A2 C D], @repository.series.map(&:name)
        assert_equal "Anglais", @repository.materials.first.name
        assert_equal "literature", @repository.materials.first.category
        assert_instance_of Entities::Catalog::Series, @repository.series.first
      end

      test "retrouve chaque élément par son slug, nil sinon" do
        seed_referential

        assert_equal [ "1ère", "second" ], @repository.find_level(slug: "1ere").then { [ it.name, it.cycle ] }
        assert_equal "A1", @repository.find_series(slug: "a1").name
        assert_equal "PC", @repository.find_material(slug: "physique-chimie").shortname
        assert_nil @repository.find_level(slug: "inconnu")
        assert_nil @repository.find_series(slug: "inconnu")
        assert_nil @repository.find_material(slug: "inconnu")
      end

      test "crée un niveau avec son slug figé, puis le renomme sans changer le slug" do
        created = @repository.create_level(level: level).value

        assert_equal "tle", created.slug
        created.name = "Terminale"

        updated = @repository.update_level(level: created).value

        assert_equal [ "Terminale", "tle" ], [ updated.name, updated.slug ]
      end

      test "un niveau en conflit nomme le champ pris" do
        @repository.create_level(level: level)

        assert_equal({ name: [ :taken ] }, @repository.create_level(level: level(position: 8)).errors)
        assert_equal({ position: [ :taken ] }, @repository.create_level(level: level(name: "Terminale")).errors)
      end

      test "crée, renomme et refuse une série en doublon" do
        created = @repository.create_series(series: Entities::Catalog::Series.new(name: "D")).value
        created.name = "D1"

        assert_equal [ "D1", "d" ], @repository.update_series(series: created).value.then { [ it.name, it.slug ] }
        assert_equal({ name: [ :taken ] }, @repository.create_series(series: Entities::Catalog::Series.new(name: "D1")).errors)
      end

      test "crée, modifie et refuse une matière en doublon de nom ou d'abrégé" do
        created = @repository.create_material(material: material).value
        created.category = "other"

        assert_equal "other", @repository.update_material(material: created).value.category
        assert_equal({ name: [ :taken ] }, @repository.create_material(material: material(shortname: "Bio")).errors)
        assert_equal({ shortname: [ :taken ] }, @repository.create_material(material: material(name: "Biologie")).errors)
      end

      test "supprime un élément libre, refuse un élément utilisé" do
        free_level, used_level = create_level, create_level
        free_series, used_series = create_series, create_series
        free_material, used_material = create_material, create_material
        create_course(level: used_level, material: used_material, series: used_series)

        assert @repository.delete_level(id: free_level.id).success?
        assert @repository.delete_series(id: free_series.id).success?
        assert @repository.delete_material(id: free_material.id).success?
        assert_not Orm::Level.exists?(free_level.id)
        assert_equal({ base: [ :referenced ] }, @repository.delete_level(id: used_level.id).errors)
        assert_equal :conflict, @repository.delete_series(id: used_series.id).code
        assert_equal :conflict, @repository.delete_material(id: used_material.id).code
      end

      test "un niveau ou une série liés, une classe ou un enseignant les retiennent aussi" do
        pair = link_level_series
        classroom = create_classroom
        teacher_material = create_teacher.teacher_profile.material

        assert_equal :conflict, @repository.delete_level(id: pair.level_id).code
        assert_equal :conflict, @repository.delete_series(id: pair.series_id).code
        assert_equal :conflict, @repository.delete_level(id: classroom.level_id).code
        assert_equal :conflict, @repository.delete_material(id: teacher_material.id).code
      end

      test "lie une série à un niveau une seule fois, et délie un couple inutilisé" do
        level, series = create_level, create_series

        assert @repository.link(level_id: level.id, series_id: series.id, at: @at).success?
        assert_equal({ base: [ :already_linked ] }, @repository.link(level_id: level.id, series_id: series.id, at: @at).errors)
        assert @repository.unlink(level_id: level.id, series_id: series.id).success?
        assert_not Orm::LevelSeries.exists?(level:, series:)
      end

      test "refuse de délier un couple porté par une classe ou un cours" do
        [ ->(pair) { create_classroom(level: pair.level, series: pair.series) },
          ->(pair) { create_course(level: pair.level, series: pair.series) } ].each do |use|
          pair = link_level_series
          use.call(pair)

          assert_equal({ base: [ :referenced ] }, @repository.unlink(level_id: pair.level_id, series_id: pair.series_id).errors)
          assert Orm::LevelSeries.exists?(pair.id)
        end
      end

      test "construit l'index en mémoire du référentiel" do
        referential = seed_referential

        lookup = @repository.lookup

        assert_equal "physique-chimie", lookup.resolve_material("Physique Chimie").slug
        assert lookup.pair?(referential[:levels]["tle"].id, referential[:series]["d"].id)
        assert_equal %w[a c], lookup.series_for(referential[:levels]["2nde"].id).map(&:slug)
      end
    end
  end
end
