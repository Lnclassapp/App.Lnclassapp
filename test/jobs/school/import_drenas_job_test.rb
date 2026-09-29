require "test_helper"

# DR-02, DR-06, ADR-0055: the delivered file of the 41 DRENA is imported on an empty base, each with its slug drena-…;
# a file of another format, of another version or over 500 lines is rejected in bloc, and nothing is created.
class School::ImportDrenasJobTest < ActiveJob::TestCase
  DELIVERED = Rails.root.join("db/seeds/data/imports/drenas-2026.json")

  def import(document)
    report = create_import_report(kind: "drenas")
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, io: StringIO.new(document.to_json), filename: "drenas.json")

    School::ImportDrenasJob.perform_now(report.id)

    report.reload
  end

  def document(names) = { "format" => "lnclass.drenas", "version" => 1, "drenas" => names.map { { "name" => it } } }

  test "DR-02 the delivered file on an empty base: completed, 41 imported, each slug drawn from its name" do
    delivered = JSON.parse(DELIVERED.read)
    names = delivered.fetch("drenas").pluck("name")

    report = import(delivered)

    assert_equal [ "completed", 41, 41, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({}, report.details)
    assert_equal names.sort, Orm::Drena.pluck(:name).sort
    assert_equal names.to_h { [ it, Entities::School::Drena.slug_for(it) ] }, Orm::Drena.pluck(:name, :slug).to_h
    assert(Orm::Drena.pluck(:slug).all? { it.start_with?("drena-") })
    assert_equal 41, Orm::Drena.distinct.count(:public_id)

    again = import(delivered)

    assert_equal [ "completed", 41, 0, 41, 0 ], again.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal 41, Orm::Drena.count
  end

  test "DR-06 another format, another version or 501 lines: the report is rejected, and no DRENA is created" do
    schools = import(document([ "Man" ]).merge("format" => "lnclass.schools"))
    assert_equal [ "rejected", [ "format" ] ], [ schools.status, schools.import_errors.pluck("path") ]

    version = import(document([ "Man" ]).merge("version" => 2))
    assert_equal [ "rejected", [ "version" ] ], [ version.status, version.import_errors.pluck("path") ]

    oversized = import(document(Array.new(501) { "DRENA #{it + 1}" }))
    assert_equal "rejected", oversized.status
    assert_equal [ { "path" => "drenas", "code" => "too_many_roots", "params" => { "max" => 500, "count" => 501 } } ],
                 oversized.import_errors

    assert_equal 0, Orm::Drena.count
  end

  test "it runs the DRENA adapter" do
    assert_instance_of UseCases::School::ImportDrenas, School::ImportDrenasJob.new.send(:adapter)
    assert_equal "School::ImportDrenasJob", Rails.configuration.x.import_jobs.fetch(UseCases::School::ImportDrenas::KIND)
  end
end
