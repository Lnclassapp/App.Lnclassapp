require "test_helper"

# ADR-0039: the job of an import kind wires RunImport on the real repositories; FakeImportJob plugs the fake
# adapter and the test schema in.
class Shared::ImportJobTest < ActiveJob::TestCase
  def queued_report(document)
    create_import_report(kind: "schools").tap do |report|
      Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, io: StringIO.new(document.to_json),
                                                        filename: "ecoles.json")
    end
  end

  test "a mixed file ends completed, with exact counts, errors at their path and an audit event" do
    report = queued_report(mixed(schools_document(count: 10, drena: "abidjan-2")))
    FakeImportJob.importer_options = { existing: [ "Lycée Moderne 9" ] }

    assert_difference -> { Orm::AuditEvent.where(action: "import.run").count } do
      FakeImportJob.perform_now(report.id)
    end

    report.reload
    assert_equal "completed", report.status
    assert_equal [ 10, 6, 2, 2 ], report.values_at(:total_count, :imported_count, :skipped_count, :error_count)
    assert_equal [ "schools[3].name", "schools[7].name" ], report.import_errors.pluck("path")
    assert_equal({ "classrooms" => 12 }, report.details)
  ensure
    FakeImportJob.importer_options = {}
  end

  test "an element refused by the test schema is reported at its JSON path" do
    document = schools_document(count: 2, drena: "abidjan-2").tap { it["schools"][1]["name"] = 42 }
    report = queued_report(document)

    FakeImportJob.perform_now(report.id)

    report.reload
    assert_equal [ 1, 1 ], report.values_at(:imported_count, :error_count)
    assert_equal [ { "path" => "schools[1].name", "code" => "schema", "params" => { "keyword" => "string" } } ],
                 report.import_errors
  end

  test "the abstract job has no adapter and leaves the report queued" do
    report = queued_report(schools_document(count: 1, drena: "abidjan-2"))

    error = assert_raises(NotImplementedError) { Shared::ImportJob.perform_now(report.id) }

    assert_match "Shared::ImportJob doit définir #adapter", error.message
    assert_equal "queued", report.reload.status
  end

  test "the schemas are read from config/schemas by default" do
    validator = Shared::ImportJob.new.send(:schema_validator)

    assert_instance_of Repositories::Catalog::ImportSchemaValidator, validator
    assert_equal Rails.root.join("config/schemas"), validator.root
  end

  test "one import of a kind runs at a time, whatever the report" do
    assert_equal 1, FakeImportJob.concurrency_limit
    assert_equal FakeImportJob.new(1).concurrency_key, FakeImportJob.new(2).concurrency_key
    assert_includes FakeImportJob.new(1).concurrency_key, "FakeImportJob"
  end

  test "a job whose argument can no longer be read is discarded" do
    assert_includes Shared::ImportJob.rescue_handlers.map(&:first), "ActiveJob::DeserializationError"
  end
end
