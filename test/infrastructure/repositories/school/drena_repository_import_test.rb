require "test_helper"

module Repositories
  module School
    # ADR-0066 : écritures en masse de l'import des DRENA, slug et public_id calculés par l'adaptateur.
    class DrenaRepositoryImportTest < ActiveSupport::TestCase
      setup { @repository = DrenaRepository.new }

      def row(name, slug) = { public_id: SecureRandom.base58(14), name:, slug: }

      test "les noms pris sont ceux de la base, tels qu'écrits" do
        create_drena(name: "Bouake 1")
        create_drena(name: "Man")

        assert_equal Set["Bouake 1", "Man"], @repository.taken_names
      end

      test "sans DRENA, aucun nom n'est pris" do
        assert_equal Set.new, @repository.taken_names
      end

      test "insère toutes les lignes d'un lot avec leurs slug, public_id et horodatage" do
        at = Time.zone.parse("2026-09-29 10:00")

        written = @repository.insert_many(rows: [ row("Bouaké 1", "drena-bouake-1"), row("San-Pédro", "drena-san-pedro") ], at:)

        assert_equal 2, written
        bouake = Orm::Drena.find_by!(slug: "drena-bouake-1")
        assert_equal [ "Bouaké 1", 14, at ], [ bouake.name, bouake.public_id.length, bouake.created_at ]
        assert Orm::Drena.exists?(slug: "drena-san-pedro", name: "San-Pédro")
      end

      test "un lot vide n'écrit rien" do
        assert_equal 0, @repository.insert_many(rows: [], at: Time.current)
      end

      test "une violation d'unicité lève : le moteur annule le lot" do
        create_drena(name: "Man")

        assert_raises(ActiveRecord::RecordNotUnique) do
          @repository.insert_many(rows: [ row("Man", "drena-man-bis") ], at: Time.current)
        end
      end
    end
  end
end
