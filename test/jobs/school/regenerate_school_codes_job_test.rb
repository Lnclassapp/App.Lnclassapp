require "test_helper"

# ADR-0096, RM-02 to RM-05, RM-12, RM-14, RM-21: the job changes the codes of the selected schools on the real repositories,
# and nothing else; neither the report nor the audit keeps a code.
class School::RegenerateSchoolCodesJobTest < ActiveJob::TestCase
  setup do
    @abidjan = create_drena(name: "Abidjan 1")
    @author = create_team_member(second_factor: false)
    @launch = 1.minute.ago.change(usec: 0)
  end

  def launch(selection, expected_count: 0)
    create_import_report(kind: "school_codes", checksum_sha256: nil, imported_by: @author, created_at: @launch,
                         details: { "selection" => selection.merge("school_year" => nil), "expected_count" => expected_count })
  end

  test "RM-02, RM-04, RM-14: the codes of the DRENA change, distinct and dated; the others, the invite tokens and the staff do not" do
    schools = Array.new(3) { create_school(drena: @abidjan, name: "Lycée #{it}", created_at: @launch - 1.day) }
    elsewhere = create_school(drena: create_drena(name: "Bouaké"), created_at: @launch - 1.day)
    late = create_school(drena: @abidjan, name: "Lycée importé pendant le job", created_at: @launch + 10.seconds)
    staff = create_school_admin(school: schools.first)
    before = Orm::School.pluck(:id, :school_code, :direction_invite_token, :team_invite_token).to_h { [ it.first, it.drop(1) ] }
    report = launch({ "drena" => @abidjan.public_id }, expected_count: 3)

    School::RegenerateSchoolCodesJob.perform_now(report.id)

    report.reload
    assert_equal [ "completed", 3, 3, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    schools.each(&:reload)
    assert(schools.all? { it.school_code != before[it.id].first && Entities::School::SchoolCode.valid?(it.school_code) })
    assert(schools.all? { it.school_code_rotated_at >= @launch })
    assert_equal Orm::School.count, Orm::School.distinct.count(:school_code)
    assert_equal before[elsewhere.id].first, elsewhere.reload.school_code
    assert_equal before[late.id].first, late.reload.school_code
    assert_equal before.transform_values { it.drop(1) }, Orm::School.pluck(:id, :direction_invite_token, :team_invite_token).to_h { [ it.first, it.drop(1) ] }
    assert_equal schools.first.id, Orm::SchoolStaff.find_by!(user_id: staff.id).school_id
  end

  test "RM-03: the old code finds no school any more, the new one does" do
    school = create_school(drena: @abidjan, created_at: @launch - 1.day)
    old_code = school.school_code

    School::RegenerateSchoolCodesJob.perform_now(launch({ "drena" => @abidjan.public_id }).id)

    repository = Repositories::School::SchoolRepository.new
    assert_nil repository.find_by_school_code(school_code: old_code)
    assert_equal school.id, repository.find_by_school_code(school_code: school.reload.school_code).id
  end

  test "RM-05, RM-12: one school.changed per school with the report, one import.run; no code in the report nor in the audit" do
    schools = Array.new(2) { create_school(drena: @abidjan, created_at: @launch - 1.day) }
    report = launch({ "drena" => @abidjan.public_id }, expected_count: 2)

    School::RegenerateSchoolCodesJob.perform_now(report.id)

    events = Orm::AuditEvent.where(action: "school.changed").order(:subject_id)
    assert_equal schools.map(&:id).sort, events.map(&:subject_id)
    assert_equal({ "change" => "code_regenerated", "public_id" => schools.min_by(&:id).public_id, "report_public_id" => report.public_id },
                 events.first.metadata)
    assert Orm::AuditEvent.exists?(action: "import.run", subject_id: report.id, actor_id: @author.id)
    codes = Orm::School.pluck(:school_code)
    stored = [ report.reload.attributes.to_json, Orm::AuditEvent.pluck(:metadata).to_json ].join
    assert(codes.none? { stored.include?(it) })
  end

  test "RM-21: the same report run again changes nothing" do
    school = create_school(drena: @abidjan, created_at: @launch - 1.day)
    report = launch({ "drena" => @abidjan.public_id })
    School::RegenerateSchoolCodesJob.perform_now(report.id)
    code = school.reload.school_code

    School::RegenerateSchoolCodesJob.perform_now(report.id)

    assert_equal code, school.reload.school_code
    assert_equal 1, Orm::AuditEvent.where(action: "school.changed").count
  end
end
