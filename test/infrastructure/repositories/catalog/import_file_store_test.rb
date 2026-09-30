require "test_helper"

module Repositories
  module Catalog
    class ImportFileStoreTest < ActiveSupport::TestCase
      Upload = Data.define(:io, :filename)

      setup do
        @store = ImportFileStore.new
        @report = create_import_report
      end

      test "rattache le fichier au rapport par Active Storage et le relit tel quel" do
        json = { format: "lnclass.schools", version: 1, schools: [ { name: "Lycée d'Abidjan" } ] }.to_json

        assert @store.attach(report_id: @report.id, files: [ Upload.new(io: StringIO.new(json), filename: "ecoles.json") ])
        assert_equal [ Entities::Catalog::ImportFile.new(name: "ecoles.json", content: json) ], @store.read(report_id: @report.id)
        assert_equal Encoding::UTF_8, @store.read(report_id: @report.id).first.content.encoding
        assert_equal [ [ "ecoles.json", "application/json" ] ], @report.reload.sources.map { [ it.filename.to_s, it.content_type ] }
      end

      # ADR-0068 : plusieurs fichiers, relus dans l'ordre d'envoi, deux noms identiques compris.
      test "rattache plusieurs fichiers et les relit dans l'ordre d'envoi" do
        uploads = [ [ "z.json", "{\"z\":1}" ], [ "a.json", "{\"a\":1}" ], [ "z.json", "{\"z\":2}" ] ]
                  .map { |filename, json| Upload.new(io: StringIO.new(json), filename:) }

        @store.attach(report_id: @report.id, files: uploads)

        assert_equal [ [ "z.json", "{\"z\":1}" ], [ "a.json", "{\"a\":1}" ], [ "z.json", "{\"z\":2}" ] ],
                     @store.read(report_id: @report.id).map { [ it.name, it.content ] }
      end

      test "un rapport sans fichier relit une liste vide" do
        assert_equal [], @store.read(report_id: @report.id)
      end

      # securite.md n° 28 : l'ancien écrivait tmp/imports/<uuid>_<nom du client>.
      test "aucun fichier écrit sous tmp/ ne porte le nom du client ; la clé de stockage est aléatoire" do
        filename = "ecoles-#{SecureRandom.hex(6)}.json"

        @store.attach(report_id: @report.id, files: [ Upload.new(io: StringIO.new("{}"), filename:) ])

        assert_empty Dir[Rails.root.join("tmp/**/*#{filename.delete_suffix('.json')}*")]
        assert_not Rails.root.join("tmp/imports").exist?
        assert_not_includes @report.reload.sources.first.blob.key, filename
      end
    end
  end
end
