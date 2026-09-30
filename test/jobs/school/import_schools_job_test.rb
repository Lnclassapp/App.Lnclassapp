require "test_helper"

# ADR-0039: a file of the old application, once enveloped, is imported with its classrooms (SC-08, SC-09).
class School::ImportSchoolsJobTest < ActiveJob::TestCase
  # Classes of the extract with the development referential: 4 public lycées (77), 2 private or mixed schools
  # of both cycles (38), 1 private lycée (38) and 3 private collèges (12).
  EXPECTED_CLASSROOMS = (4 * 77) + (2 * 38) + 38 + (3 * 12)

  setup do
    seed_referential
    create_drena(name: "Abidjan 2")
  end

  test "the real extract of the old application is written, schools and classrooms, and the report is completed" do
    report = create_import_report(kind: "schools")
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files: [ import_upload(io: StringIO.new(import_sample("schools_legacy_sample").to_json),
                                                      filename: "schools_abidjan_2.json") ])

    School::ImportSchoolsJob.perform_now(report.id)

    report.reload
    assert_equal [ "completed", 10, 10, 0, 0 ],
                 report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "classrooms_created" => EXPECTED_CLASSROOMS }, report.details)
    assert_equal 10, Orm::School.joins(:drena).where(drenas: { slug: "drena-abidjan-2" }).count
    assert_equal EXPECTED_CLASSROOMS, Orm::Classroom.count
    notre_dame = Orm::School.find_by!(name: "Collège Notre Dame d'Afrique")
    assert_equal [ "CNDA", "private", "first", "active" ], [ notre_dame.sigle, notre_dame.school_type, notre_dame.cycle, notre_dame.status ]
    assert_equal "mixed", Orm::School.find_by!(name: "Groupe Scolaire Les Lauréades").school_type
  end

  test "it runs the schools adapter" do
    assert_instance_of UseCases::School::ImportSchools, School::ImportSchoolsJob.new.send(:adapter)
    assert_equal "School::ImportSchoolsJob", Rails.configuration.x.import_jobs.fetch(UseCases::School::ImportSchools::KIND)
  end
end
