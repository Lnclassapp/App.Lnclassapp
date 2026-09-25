require "test_helper"

module Repositories
  module Catalog
    class ImportFileStoreTest < ActiveSupport::TestCase
      setup do
        @store = ImportFileStore.new
        @report = create_import_report
      end

      test "rattache le fichier au rapport par Active Storage et le relit tel quel" do
        json = { format: "lnclass.schools", version: 1, schools: [ { name: "Lycée d'Abidjan" } ] }.to_json

        assert @store.attach(report_id: @report.id, io: StringIO.new(json), filename: "ecoles.json")
        assert_equal json, @store.read(report_id: @report.id)
        assert_equal Encoding::UTF_8, @store.read(report_id: @report.id).encoding
        assert_equal [ "ecoles.json", "application/json" ], @report.reload.source.blob.then { [ it.filename.to_s, it.content_type ] }
      end

      # securite.md n° 28 : l'ancien écrivait tmp/imports/<uuid>_<nom du client>.
      test "aucun fichier écrit sous tmp/ ne porte le nom du client ; la clé de stockage est aléatoire" do
        filename = "ecoles-#{SecureRandom.hex(6)}.json"

        @store.attach(report_id: @report.id, io: StringIO.new("{}"), filename:)

        assert_empty Dir[Rails.root.join("tmp/**/*#{filename.delete_suffix('.json')}*")]
        assert_not Rails.root.join("tmp/imports").exist?
        assert_not_includes @report.reload.source.blob.key, filename
      end
    end
  end
end
