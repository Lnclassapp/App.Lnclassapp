require "test_helper"

module Repositories
  module School
    class DrenaRepositoryTest < ActiveSupport::TestCase
      setup { @repository = DrenaRepository.new }

      def drena(name) = Entities::School::Drena.new(name:)

      test "liste les DRENA en entités, triées par nom" do
        create_drena(name: "Yamoussoukro")
        create_drena(name: "Abidjan 1")

        drenas = @repository.all

        assert_equal [ "Abidjan 1", "Yamoussoukro" ], drenas.map(&:name)
        assert_instance_of Entities::School::Drena, drenas.first
      end

      test "retrouve une DRENA par public_id ou par slug, nil sinon" do
        record = create_drena(name: "Abidjan 2")

        assert_equal record.id, @repository.find_by_public_id(public_id: record.public_id).id
        assert_equal "abidjan-2", @repository.find_by_slug(slug: "abidjan-2").slug
        assert_nil @repository.find_by_slug(slug: "inconnue")
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "crée une DRENA avec son slug dérivé du nom" do
        result = @repository.create(drena: drena("Bouaké 1"))

        assert result.success?
        assert_equal "bouake-1", result.value.slug
        assert_equal 14, result.value.public_id.length
        assert Orm::Drena.exists?(result.value.id)
      end

      test "un nom déjà pris donne :conflict, sans casser la transaction en cours" do
        create_drena(name: "Man")

        result = @repository.create(drena: drena("Man"))

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
        assert_equal 1, Orm::Drena.where(name: "Man").count
      end

      test "renomme une DRENA sans toucher à son slug" do
        record = create_drena(name: "Daloa")
        entity = @repository.find_by_slug(slug: "daloa")
        entity.name = "Daloa Ouest"

        result = @repository.update(drena: entity)

        assert result.success?
        assert_equal [ "Daloa Ouest", "daloa" ], record.reload.attributes.values_at("name", "slug")
      end

      test "un renommage vers un nom pris donne :conflict" do
        create_drena(name: "Korhogo")
        entity = @repository.create(drena: drena("Odienné")).value
        entity.name = "Korhogo"

        assert_equal :conflict, @repository.update(drena: entity).code
      end

      test "supprime une DRENA sans établissement, refuse sinon" do
        empty = create_drena
        used = create_school.drena

        assert @repository.delete(id: empty.id).success?
        assert_not Orm::Drena.exists?(empty.id)

        result = @repository.delete(id: used.id)

        assert_equal({ base: [ :has_schools ] }, result.errors)
        assert Orm::Drena.exists?(used.id)
      end

      test "indexe les identifiants par slug pour les imports" do
        record = create_drena(name: "San Pedro")

        assert_equal record.id, @repository.ids_by_slug["san-pedro"]
      end
    end
  end
end
