require "test_helper"

# ADR-0056, GC-01, GC-05: the job gives their classrooms to the schools without any classroom of the year, on the
# real repositories, and never touches the others.
class Classroom::GenerateMissingClassroomsJobTest < ActiveJob::TestCase
  setup do
    seed_referential
    @drena = create_drena(name: "Abidjan 2")
    @author = create_team_member(second_factor: false)
  end

  def classrooms_of(school) = Orm::Classroom.where(school:)

  # A classroom on a level of the referential: a level created on the fly would be a level without series nor barème,
  # skipped and counted for every lycée (ADR-0058).
  def create_classroom(**) = super(level: Orm::Level.find_by!(slug: "6eme"), **)

  test "schools without a classroom of the year receive the plan of the import; the others are left as they were" do
    lycee = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    college = create_school(drena: @drena, name: "Collège Saint Paul", school_type: "private", cycle: "first")
    draft = create_school(drena: @drena, name: "Lycée brouillon", school_type: "mixed", status: "draft")
    inactive = create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    equipped = create_school(drena: @drena, name: "Lycée doté")
    kept = Array.new(3) { create_classroom(school: equipped, name: "Classe #{it + 1}") }
    archived = create_school(drena: @drena, name: "Lycée archivé")
    create_classroom(school: archived, status: "archived")
    old = create_school(drena: @drena, name: "Lycée de l'an dernier")
    create_classroom(school: old, school_year: current_school_year(on: 1.year.ago.to_date))
    report = create_import_report(kind: "classrooms", checksum_sha256: nil, imported_by: @author)

    Classroom::GenerateMissingClassroomsJob.perform_now(report.id)

    report.reload
    assert_equal [ "completed", 4, 4, 0, 0 ], report.values_at(:status, :total_count, :imported_count, :skipped_count, :error_count)
    assert_equal({ "classrooms_created" => 77 + 12 + 38 + 77 }, report.details)
    assert_equal [ 77, 12, 38, 0 ], [ lycee, college, draft, inactive ].map { classrooms_of(it).count }
    assert_equal 78, classrooms_of(old).count
    assert_equal kept.map(&:id).sort, classrooms_of(equipped).ids.sort
    assert_equal 1, classrooms_of(archived).count
    assert_equal [ current_school_year ], classrooms_of(lycee).distinct.pluck(:school_year)
    assert_equal Orm::Classroom.count, Orm::Classroom.distinct.count(:link_token)
    assert Orm::AuditEvent.exists?(action: "import.run", actor_id: @author.id, subject_id: report.id)
  end

  test "BC-06: the generation reads the barème in base, as the team left it" do
    lycee = create_school(drena: @drena, name: "Lycée Moderne")
    tle = Orm::Level.find_by!(slug: "tle")
    Orm::ClassroomPlanEntry.find_by!(school_type: "public", level: tle, series: Orm::Series.find_by!(slug: "d")).update!(count: 1)

    Classroom::GenerateMissingClassroomsJob.perform_now(create_import_report(kind: "classrooms", checksum_sha256: nil, imported_by: @author).id)

    assert_equal 77 - 5, classrooms_of(lycee).count
    assert_equal [ "Tle D 1" ], classrooms_of(lycee).where("name LIKE 'Tle D%'").pluck(:name)
  end

  test "a second run writes nothing more" do
    create_school(drena: @drena, name: "Lycée Moderne")
    Classroom::GenerateMissingClassroomsJob.perform_now(create_import_report(kind: "classrooms", checksum_sha256: nil, imported_by: @author).id)

    second = create_import_report(kind: "classrooms", checksum_sha256: nil, imported_by: @author)
    assert_no_difference -> { Orm::Classroom.count } do
      Classroom::GenerateMissingClassroomsJob.perform_now(second.id)
    end
    assert_equal [ "completed", 0 ], second.reload.values_at(:status, :total_count)
  end

  test "it is the job of the generation kind, one at a time" do
    assert_equal "Classroom::GenerateMissingClassroomsJob",
                 Rails.configuration.x.import_jobs.fetch(Entities::Catalog::ImportKind::CLASSROOM_GENERATION)
    assert_equal 1, Classroom::GenerateMissingClassroomsJob.concurrency_limit
  end
end
