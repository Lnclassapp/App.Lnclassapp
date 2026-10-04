require "test_helper"

# RE-07 to RE-10 (UDR-0068 §3.6, ADR-0062 amended on 2026-10-03): the schools of a DRENA, each with the figures of the
# DRENA row of the dashboard. The listed schools add up to that row: an inactive school still counted is listed too.
# Since the amendment of 2026-10-04, the rows are read by TeamDashboardQuery with its figures; #page searches and pages them.
class Queries::School::DrenaSchoolsQueryTest < ActiveSupport::TestCase
  Period = Entities::School::ReportingPeriod
  Query = Queries::School::DrenaSchoolsQuery

  setup do
    @abidjan = create_drena(name: "Abidjan 1")
    @level = create_level
  end

  def dashboard(drena: @abidjan, period: "7d", cache: ActiveSupport::Cache::NullStore.new)
    Queries::School::TeamDashboardQuery.new(cache:).call(period: Period.parse(period, today: Date.current),
                                                         drena_public_id: drena.respond_to?(:public_id) ? drena.public_id : drena)
  end

  # The page as the controller reads it: the figures and the rows, then a page of them.
  def schools(drena: @abidjan, period: "7d", search: nil, page: 1, cache: ActiveSupport::Cache::NullStore.new)
    board = dashboard(drena:, period:, cache:)
    Query.new.page(drena: board.drena, rows: board.school_rows, search:, page:) if board.drena
  end

  def drena_row(drena: @abidjan, period: "7d") = dashboard(drena:, period:).drenas.sole

  def figures(row) = row.to_h.values_at(:classrooms_count, :teachers_count, :students_count, :active_students_count)

  def placed_student(classroom, **) = create_student(classroom:, **)

  test "an unknown or blank DRENA reads nothing: the national view has no school rows" do
    create_school(drena: @abidjan)

    [ "inconnue", "", nil ].each do |drena|
      assert_nil schools(drena:), drena.inspect
      assert_nil dashboard(drena:).school_rows, drena.inspect
    end
  end

  test "a DRENA without any school gives an empty first page" do
    page = schools

    assert_equal Query::Drena.new(public_id: @abidjan.public_id, name: "Abidjan 1"), page.drena
    assert_empty page.rows
    assert_equal [ 1, 1, 0 ], [ page.page, page.pages, page.total ]
  end

  test "RE-07: the active schools of the DRENA with their classrooms, teachers, students and active students" do
    school = create_school(drena: @abidjan, name: "Lycée Classique d'Abidjan")
    classroom = create_classroom(school:, level: @level)
    create_classroom(school:, level: @level)
    create_teacher(school:, classrooms: [ classroom ])
    worker = placed_student(classroom)
    placed_student(classroom)
    create_exercise_session(student: worker, started_at: 1.day.ago)
    create_exercise_session(student: worker, started_at: 2.days.ago)
    empty = create_school(drena: @abidjan, name: "Collège sans classe")
    create_school(drena: create_drena(name: "Bouaké"), name: "Lycée de Bouaké").tap { create_classroom(school: it) }

    page = schools

    assert_equal [ "Lycée Classique d'Abidjan", "Collège sans classe" ], page.rows.map(&:name)
    assert_equal Query::SchoolRow.new(public_id: school.public_id, name: "Lycée Classique d'Abidjan", status: "active",
                                      classrooms_count: 2, teachers_count: 1, students_count: 2, active_students_count: 1),
                 page.rows.first
    assert_equal [ empty.public_id, 0, 0, 0, 0 ],
                 page.rows.second.to_h.values_at(:public_id, *%i[classrooms_count teachers_count students_count active_students_count])
    assert_equal 2, page.total
  end

  test "the figures follow the definitions of the DRENA row, one school at a time" do
    school = create_school(drena: @abidjan)
    classroom = create_classroom(school:, level: @level)
    create_classroom(school:, level: @level, status: "archived")
    create_classroom(school:, level: @level, school_year: "2020-2021")
    create_teacher(school:)
    create_teacher(school:, anonymized_at: Time.current)
    create_teacher(school: create_school(drena: create_drena)).tap do |elsewhere|
      Orm::TeacherSchool.create!(teacher: elsewhere, school:, primary: false)
    end
    placed_student(classroom).tap { create_exercise_session(student: it, started_at: 20.days.ago) }
    placed_student(classroom, anonymized_at: Time.current)
    placed_student(classroom).tap { Orm::ClassroomStudent.where(student: it).update_all(left_at: Time.current) }
    create_student.tap { Orm::ClassroomStudent.create!(classroom:, student: it, primary: false, joined_at: Time.current) }
    placed_student(create_classroom(school:, level: @level, status: "archived"))

    assert_equal [ 1, 1, 1, 0 ], figures(schools.rows.sole)
    assert_equal [ 1, 1, 1, 1 ], figures(schools(period: "30d").rows.sole)
  end

  test "an inactive or draft school is listed, marked by its status, only while it still has figures" do
    active = create_school(drena: @abidjan, name: "A actif")
    inactive = create_school(drena: @abidjan, name: "B fermé", status: "inactive")
    placed_student(create_classroom(school: inactive, level: @level))
    with_teacher = create_school(drena: @abidjan, name: "C brouillon", status: "draft")
    create_teacher(school: with_teacher)
    create_school(drena: @abidjan, name: "D fermé sans rien", status: "inactive")
    create_school(drena: @abidjan, name: "E brouillon sans rien", status: "draft").tap do |school|
      create_classroom(school:, level: @level, status: "archived")
      create_teacher(school:, anonymized_at: Time.current)
    end

    page = schools

    assert_equal [ [ "B fermé", "inactive" ], [ "A actif", "active" ], [ "C brouillon", "draft" ] ],
                 page.rows.map { [ it.name, it.status ] }
    assert_equal [ inactive.public_id, active.public_id, with_teacher.public_id ], page.rows.map(&:public_id)
    assert_equal 3, page.total
  end

  # RE-08: the same figures, read by the two queries on the same period, whatever the edge case.
  test "RE-08: the schools add up to the DRENA row of the dashboard, on every period" do
    first, second = create_school(drena: @abidjan), create_school(drena: @abidjan, status: "inactive")
    create_school(drena: @abidjan)
    first_class, second_class = create_classroom(school: first, level: @level), create_classroom(school: second, level: @level)
    create_classroom(school: first, level: @level)
    create_teacher(school: first, classrooms: [ first_class ])
    create_teacher(school: second)
    create_teacher(school: first, anonymized_at: Time.current)
    placed_student(first_class).tap { create_exercise_session(student: it, started_at: 1.day.ago) }
    placed_student(first_class).tap { create_exercise_session(student: it, started_at: 20.days.ago) }
    placed_student(second_class).tap { create_exercise_session(student: it, started_at: 3.days.ago) }
    placed_student(second_class).tap { create_exercise_session(student: it, started_at: 200.days.ago) }
    placed_student(first_class, anonymized_at: Time.current).tap { create_exercise_session(student: it, started_at: 1.day.ago) }
    placed_student(create_classroom(school: first, level: @level, status: "archived"))
    other = create_drena(name: "Bouaké")
    placed_student(create_classroom(school: create_school(drena: other), level: @level))

    %w[7d 30d year].each do |period|
      rows = schools(period:).rows
      row = drena_row(period:)

      assert_equal figures(row), rows.map { figures(it) }.transpose.map(&:sum), period
    end
    assert_equal [ 3, 2, 4, 3 ], figures(drena_row(period: "30d"))
    assert_equal [ 3, 2, 4, 2 ], figures(drena_row(period: "7d"))
  end

  # ADR-0062, amended on 2026-10-04: on the year view, the rows are kept in the cache entry of the figures; a change is
  # seen by both at the same time, never by one of them alone.
  test "RE-08 on the year view, with the cache: the rows are kept with the figures, and refreshed with them" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      cache = ActiveSupport::Cache::MemoryStore.new
      school = create_school(drena: @abidjan)
      classroom = create_classroom(school:, level: @level)
      placed_student(classroom)
      dashboard(period: "year", cache:)
      placed_student(classroom)

      travel 5.minutes - 1.second
      kept = schools(period: "year", cache:)
      assert_equal [ 1, 1 ], [ kept.rows.sole.students_count, dashboard(period: "year", cache:).accounts.students ]

      travel 2.seconds
      fresh = schools(period: "year", cache:)
      assert_equal [ 2, 2 ], [ fresh.rows.sole.students_count, dashboard(period: "year", cache:).accounts.students ]
    end
  end

  test "RE-09: 25 schools a page, sorted by students then name, a school without classroom included with zeros" do
    big = create_school(drena: @abidjan, name: "Lycée 30")
    classroom = create_classroom(school: big, level: @level)
    3.times { placed_student(classroom) }
    small = create_school(drena: @abidjan, name: "Lycée 29")
    placed_student(create_classroom(school: small, level: @level))
    28.times { |index| create_school(drena: @abidjan, name: format("Lycée %02d", index + 1)) }

    first = schools
    second = schools(page: 2)

    assert_equal [ 30, 2, 1 ], [ first.total, first.pages, first.page ]
    assert_equal 25, first.rows.size
    assert_equal [ "Lycée 30", "Lycée 29", "Lycée 01", "Lycée 02" ], first.rows.first(4).map(&:name)
    assert_equal [ 3, 1, 0 ], first.rows.first(3).map(&:students_count)
    assert_equal [ "Lycée 24", "Lycée 25", "Lycée 26", "Lycée 27", "Lycée 28" ], second.rows.map(&:name)
    assert_equal 2, second.page
  end

  test "a page out of range reads the last one, an invalid page the first one" do
    27.times { |index| create_school(drena: @abidjan, name: format("Lycée %02d", index + 1)) }

    assert_equal [ 2, 2 ], schools(page: 99).then { [ it.page, it.rows.size ] }
    [ "abc", nil, "", "0", "-3", [ "2" ] ].each do |page|
      assert_equal [ 1, 25 ], schools(page:).then { [ it.page, it.rows.size ] }, page.inspect
    end
    assert_equal 2, schools(page: "2").page
  end

  test "RE-10: the search reads the names of every page, without case or accents, inside the DRENA only" do
    26.times { |index| create_school(drena: @abidjan, name: format("Collège %02d", index + 1)) }
    cocody = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
    create_school(drena: create_drena(name: "Abidjan 2"), name: "Lycée Moderne de Cocody")
    assert_includes schools(page: 2).rows.map(&:public_id), cocody.public_id

    [ "cocody", "  COCODY ", "lycee moderne" ].each do |search|
      page = schools(search:)

      assert_equal [ cocody.public_id ], page.rows.map(&:public_id), search
      assert_equal [ 1, 1, 1 ], [ page.total, page.page, page.pages ], search
    end
    assert_equal [ 9, 9 ], [ "collège 0", "COLLEGE 0" ].map { schools(search: it).total }
    assert_empty schools(search: "zzz").rows
    assert_equal 0, schools(search: "zzz").total
    assert_equal 27, schools(search: "").total
  end

  test "the search treats LIKE wildcards as plain text" do
    create_school(drena: @abidjan, name: "Lycée 100% réussite")
    create_school(drena: @abidjan, name: "Lycée A")

    assert_equal [ "Lycée 100% réussite" ], schools(search: "100%").rows.map(&:name)
    assert_empty schools(search: "_").rows
  end

  test "the number of queries does not grow with the schools of the DRENA: one for the rows, one for a search" do
    seed_schools(2)
    since = Period.parse("7d", today: Date.current).since.in_time_zone
    read = -> { Query.new.rows(drena_id: @abidjan.id, year: Entities::Classroom::SchoolYear.current(Date.current), since:) }
    small = count_queries(&read)
    seed_schools(30)
    rows = read.call
    drena = Query::Drena.new(public_id: @abidjan.public_id, name: @abidjan.name)

    assert_equal [ 1, 1 ], [ small, count_queries(&read) ]
    assert_equal 0, count_queries { Query.new.page(drena:, rows:, page: 2) }
    assert_equal 1, count_queries { Query.new.page(drena:, rows:, search: "lycée", page: 2) }
  end

  private

  def seed_schools(count)
    count.times do
      school = create_school(drena: @abidjan)
      classroom = create_classroom(school:, level: @level)
      create_teacher(school:, classrooms: [ classroom ])
      create_exercise_session(student: placed_student(classroom), started_at: 1.day.ago)
    end
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
