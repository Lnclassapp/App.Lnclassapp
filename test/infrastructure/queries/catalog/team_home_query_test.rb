require "test_helper"

# TR-09, CA-25 (UDR-0018): the team home reads the real tables, with no cache. The old feed read an Orm constant that had
# disappeared, and the referential was served by two concurrent 12-hour caches.
class Queries::Catalog::TeamHomeQueryTest < ActiveSupport::TestCase
  setup do
    @query = Queries::Catalog::TeamHomeQuery.new
  end

  # Action Text and Active Storage touch their record on save: the update time is set once everything is written.
  def updated(record, at)
    record.tap { it.update_columns(updated_at: at) }
  end

  test "an empty production counts nothing and lists nothing" do
    home = @query.call

    assert_equal [ 0, 0, 0, 0, 0 ], home.to_h.values_at(:drenas_count, :schools_count, :classrooms_count, :series_count, :materials_count)
    assert_empty home.levels
    assert_empty home.recent_courses
    assert_empty home.recent_exercises
    assert_empty home.recent_imports
  end

  test "the counters read DRENA, schools, active classrooms of the school year, series and materials" do
    drena = create_drena
    school = create_school(drena:, status: "inactive")
    create_school(drena:)
    create_drena
    create_classroom(school:)
    create_classroom(school:)
    create_classroom(school:, status: "archived")
    create_classroom(school:, school_year: "2020-2021")
    2.times { create_series }
    3.times { create_material }

    home = @query.call

    assert_equal 2, home.drenas_count
    assert_equal 2, home.schools_count
    assert_equal 2, home.classrooms_count
    assert_equal 2, home.series_count
    assert_equal 3, home.materials_count
  end

  test "the school year of the classrooms counter follows the given day" do
    create_classroom(school_year: "2026-2027")

    assert_equal 1, @query.call(today: Date.new(2027, 8, 15)).classrooms_count
    assert_equal 0, @query.call(today: Date.new(2027, 9, 1)).classrooms_count
  end

  test "levels come by position, each with its linked series sorted by name" do
    tle = create_level(name: "Tle", position: 7)
    sixth = create_level(name: "6ème", position: 1)
    link_level_series(level: tle, series: create_series(name: "D"))
    link_level_series(level: tle, series: create_series(name: "A1"))

    levels = @query.call.levels

    assert_equal [ "6ème", "Tle" ], levels.map(&:name)
    assert_equal [ [], %w[A1 D] ], levels.map(&:series_names)
    assert_equal sixth.slug, levels.first.slug
  end

  test "the five last courses by update, every status, with their level and subject" do
    material = create_material(name: "SVT", category: "science")
    level = create_level(name: "Tle")
    courses = %w[draft published archived draft published draft].each_with_index.map do |status, index|
      updated(create_course(level:, material:, status:, name: "Cours #{index}"), index.days.ago)
    end

    recent = @query.call.recent_courses

    assert_equal courses.first(5).map(&:slug), recent.map(&:slug)
    assert_equal %w[draft published archived draft published], recent.map(&:status)
    assert_equal [ "Cours 0", "Tle", "SVT", "science" ], recent.first.to_h.values_at(:name, :level_name, :material_name, :material_category)
  end

  test "the five last exercises by update, every status, with their essential" do
    essential = create_essential(name: "La méiose")
    exercises = 6.times.map do |index|
      updated(create_exercise(essential:, questions: 0, status: index.even? ? "draft" : "published"), index.hours.ago)
    end

    recent = @query.call.recent_exercises

    assert_equal exercises.first(5).map(&:public_id), recent.map(&:public_id)
    assert_equal %w[draft published draft published draft], recent.map(&:status)
    assert_equal [ exercises.first.title, "La méiose" ], recent.first.to_h.values_at(:title, :essential_name)
  end

  test "the five last imports by update, every status and kind, with their file name when it is attached" do
    member = create_team_member(second_factor: false)
    # One running import per kind (ADR-0039): queued, importing and validating each get their own kind.
    statuses = { "queued" => "schools", "completed" => "schools", "rejected" => "exercises", "failed" => "exercises",
                 "importing" => "course_tree", "validating" => "essentials" }
    reports = statuses.each_with_index.map do |(status, kind), index|
      report = create_import_report(status:, kind:, imported_by: member)
      report.source.attach(io: StringIO.new("{}"), filename: "etablissements.json", content_type: "application/json") if index.zero?
      updated(report, index.minutes.ago)
    end

    recent = @query.call.recent_imports

    assert_equal reports.first(5).map(&:public_id), recent.map(&:public_id)
    assert_equal %w[queued completed rejected failed importing], recent.map(&:status)
    assert_equal [ "schools", "etablissements.json" ], recent.first.to_h.values_at(:kind, :filename)
    assert_nil recent.second.filename
  end

  test "ties on the update keep the latest created first" do
    at = Time.current
    first = updated(create_course, at)
    second = updated(create_course, at)

    assert_equal [ second.slug, first.slug ], @query.call.recent_courses.map(&:slug)
  end

  test "the lazy frame reads the recent lists alone, as the home does" do
    create_course
    create_exercise(questions: 0)
    create_import_report

    home = @query.call

    assert_equal home.recent_courses, @query.recent_courses
    assert_equal home.recent_exercises, @query.recent_exercises
    assert_equal home.recent_imports, @query.recent_imports
  end
end
