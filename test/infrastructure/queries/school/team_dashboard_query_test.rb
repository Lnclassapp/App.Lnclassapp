require "test_helper"

# TR-10, TR-12 (ADR-0062, UDR-0049): the team dashboard reads aggregated indicators straight from the business tables.
# The old « Control Center » had no test at all and broke on a renamed method; here every definition of ADR-0062 §4
# has its own test, and the number of queries is checked against the volume.
class Queries::School::TeamDashboardQueryTest < ActiveSupport::TestCase
  Period = Entities::School::ReportingPeriod
  Query = Queries::School::TeamDashboardQuery

  def dashboard(period: "7d", drena: nil) = Query.new.call(period: Period.parse(period, today: Date.current), drena_public_id: drena)

  # A student placed in an active classroom of the school year (ADR-0040, ADR-0041).
  def placed_student(classroom, **) = create_student(classroom:, **)

  # Content has a team author: one, created long ago, so that it never counts as a signup of the period.
  def an_exercise
    @essential ||= create_essential(course: create_course(author: create_team_member(second_factor: false, created_at: 1.year.ago)))
    create_exercise(essential: @essential)
  end

  test "an empty base counts zero everywhere, has no success rate and lists nothing" do
    board = dashboard

    assert_equal [ 0, 0, 0, 0 ], board.to_h.values_at(:signups_count, :active_students_count, :completed_sessions_count, :assignments_count)
    assert_nil board.average_score
    assert_equal Query::Accounts.new(students: 0, teachers: 0, team: 0), board.accounts
    assert_equal Query::Coverage.new(active: 0, with_classroom: 0, with_teacher: 0, with_student: 0), board.schools
    assert_equal 0, board.classrooms_count
    assert_equal 0, board.placed_students_count
    assert_equal 0, board.unplaced_students_count
    assert_empty board.levels
    assert_empty board.drenas
    assert_empty board.recent_signups
    assert_nil board.drena
    assert_equal "7d", board.period.key
    assert_equal Entities::Classroom::SchoolYear.current(Date.current), board.school_year
  end

  test "active accounts by role leave the anonymized ones out" do
    2.times { create_student }
    create_student(anonymized_at: Time.current)
    create_teacher
    create_team_member
    create_user(role: "school_admin")

    assert_equal Query::Accounts.new(students: 2, teachers: 1, team: 1), dashboard.accounts
  end

  test "the flow indicators follow the period: signups, active students, completed exercises, success rate, assignments" do
    classroom = create_classroom
    recent = placed_student(classroom, created_at: 3.days.ago)
    older = placed_student(classroom, created_at: 20.days.ago)
    create_student(created_at: 60.days.ago)
    create_student(created_at: 1.day.ago, anonymized_at: Time.current)
    exercise = an_exercise
    create_exercise_session(student: recent, exercise:, started_at: 2.days.ago)
    create_exercise_session(student: recent, exercise: an_exercise, status: "completed", score_percent: 80,
                            started_at: 1.day.ago, completed_at: 1.day.ago)
    create_exercise_session(student: recent, exercise: an_exercise, status: "completed", score_percent: 61,
                            started_at: 6.days.ago.beginning_of_day, completed_at: 6.days.ago.beginning_of_day)
    create_exercise_session(student: older, exercise:, status: "completed", score_percent: 10,
                            started_at: 20.days.ago, completed_at: 20.days.ago)
    teacher = create_teacher(school: classroom.school, classrooms: [ classroom ], created_at: 40.days.ago)
    create_assignment(classroom:, assignable: an_exercise, by: teacher, assigned_at: 2.days.ago)
    create_assignment(classroom:, assignable: an_exercise, by: teacher, assigned_at: 20.days.ago, status: "archived")

    week = dashboard(period: "7d")

    assert_equal [ 1, 1, 2, 71, 1 ],
                 week.to_h.values_at(:signups_count, :active_students_count, :completed_sessions_count, :average_score, :assignments_count)

    month = dashboard(period: "30d")

    assert_equal [ 2, 2, 3, 50, 2 ],
                 month.to_h.values_at(:signups_count, :active_students_count, :completed_sessions_count, :average_score, :assignments_count)
  end

  test "a session started on the first day of the period, at midnight, is in; the day before is out" do
    student = create_student
    since = Period.parse("7d", today: Date.current).since.in_time_zone
    create_exercise_session(student:, started_at: since)
    create_exercise_session(student: create_student, started_at: since - 1.second)

    assert_equal 1, dashboard.active_students_count
  end

  test "the school year period starts on September 1st" do
    student = create_student(created_at: Period.parse("year", today: Date.current).since.in_time_zone + 1.hour)

    assert_equal 1, dashboard(period: "year").signups_count
    assert_equal student.created_at > 30.days.ago ? 1 : 0, dashboard(period: "30d").signups_count
  end

  test "school coverage reads active schools, active classrooms of the year, active teachers and placed students" do
    full = create_school
    classroom = create_classroom(school: full)
    create_teacher(school: full)
    placed_student(classroom)
    with_teacher_only = create_school
    create_teacher(school: with_teacher_only, anonymized_at: Time.current)
    create_teacher(school: with_teacher_only)
    empty = create_school
    create_classroom(school: empty, status: "archived")
    create_classroom(school: empty, school_year: "2020-2021")
    inactive = create_school(status: "inactive")
    create_classroom(school: inactive)

    board = dashboard

    assert_equal Query::Coverage.new(active: 3, with_classroom: 1, with_teacher: 2, with_student: 1), board.schools
    assert_equal 2, board.classrooms_count
  end

  test "a student who left the classroom, or whose classroom is archived, is not placed" do
    classroom = create_classroom
    left = placed_student(classroom)
    Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
    placed_student(create_classroom(status: "archived"))
    placed_student(classroom)

    board = dashboard

    assert_equal 1, board.placed_students_count
    assert_equal 2, board.unplaced_students_count
    assert_equal Query::Coverage.new(active: 2, with_classroom: 1, with_teacher: 0, with_student: 1), board.schools
  end

  test "students by level, by level position, with their share of the placed students (TR-12)" do
    tle = create_level(name: "Tle", position: 7)
    sixth = create_level(name: "6ème", position: 1)
    create_level(name: "3ème", position: 4)
    3.times { placed_student(create_classroom(level: tle)) }
    placed_student(create_classroom(level: sixth))
    create_student
    placed_student(create_classroom(level: tle, status: "archived"))
    placed_student(create_classroom(level: tle), anonymized_at: Time.current)

    board = dashboard

    assert_equal [ Query::LevelShare.new(slug: "6eme", name: "6ème", students_count: 1, percent: 25),
                   Query::LevelShare.new(slug: "3eme", name: "3ème", students_count: 0, percent: 0),
                   Query::LevelShare.new(slug: "tle", name: "Tle", students_count: 3, percent: 75) ], board.levels
    assert_equal 4, board.placed_students_count
    assert_equal 2, board.unplaced_students_count
  end

  test "by DRENA: active schools, classrooms, teachers, students and active students, sorted by students then name" do
    abidjan = create_drena(name: "Abidjan 1")
    bouake = create_drena(name: "Bouaké")
    create_drena(name: "Agboville")
    abidjan_school = create_school(drena: abidjan)
    create_school(drena: abidjan, status: "draft")
    abidjan_class = create_classroom(school: abidjan_school)
    create_teacher(school: abidjan_school)
    worker = placed_student(abidjan_class)
    placed_student(abidjan_class)
    create_exercise_session(student: worker, started_at: 1.day.ago)
    create_exercise_session(student: worker, exercise: create_exercise, started_at: 2.days.ago)
    bouake_school = create_school(drena: bouake)
    bouake_class = create_classroom(school: bouake_school)
    create_classroom(school: bouake_school)
    2.times { create_teacher(school: bouake_school) }
    placed_student(bouake_class)
    create_exercise_session(student: placed_student(bouake_class), started_at: 20.days.ago)

    rows = dashboard.drenas

    assert_equal [ "Abidjan 1", "Bouaké", "Agboville" ], rows.map(&:name)
    assert_equal Query::DrenaRow.new(public_id: abidjan.public_id, name: "Abidjan 1", schools_count: 1, classrooms_count: 1,
                                     teachers_count: 1, students_count: 2, active_students_count: 1), rows.first
    assert_equal [ 1, 2, 2, 2, 0 ], rows.second.to_h.values_at(:schools_count, :classrooms_count, :teachers_count, :students_count,
                                                               :active_students_count)
    assert_equal [ 0, 0, 0, 0, 0 ], rows.third.to_h.values_at(:schools_count, :classrooms_count, :teachers_count, :students_count,
                                                              :active_students_count)
    assert_equal 1, dashboard(period: "30d").drenas.second.active_students_count
  end

  test "the DRENA filter narrows every indicator to its territory, and leaves the team out" do
    tle = create_level(name: "Tle", position: 7)
    here, there = [ "Abidjan 1", "Bouaké" ].map do |name|
      drena = create_drena(name:)
      school = create_school(drena:)
      classroom = create_classroom(school:, level: tle)
      teacher = create_teacher(school:, classrooms: [ classroom ])
      student = placed_student(classroom)
      create_exercise_session(student:, status: "completed", score_percent: name == "Bouaké" ? 20 : 90, completed_at: 1.hour.ago)
      create_assignment(classroom:, by: teacher, assigned_at: 1.day.ago)
      drena
    end
    create_student
    create_team_member

    board = dashboard(drena: here.public_id)

    assert_equal Query::Filter.new(public_id: here.public_id, name: "Abidjan 1"), board.drena
    assert_equal Query::Accounts.new(students: 1, teachers: 1, team: nil), board.accounts
    assert_equal [ 2, 1, 1, 90, 1 ],
                 board.to_h.values_at(:signups_count, :active_students_count, :completed_sessions_count, :average_score, :assignments_count)
    assert_equal Query::Coverage.new(active: 1, with_classroom: 1, with_teacher: 1, with_student: 1), board.schools
    assert_equal 1, board.classrooms_count
    assert_equal 1, board.levels.find { it.slug == "tle" }.students_count
    assert_equal 1, board.levels.sum(&:students_count)
    assert_nil board.unplaced_students_count
    assert_equal [ "Abidjan 1" ], board.drenas.map(&:name)
    assert_equal 2, board.recent_signups.size
    assert_not_includes board.recent_signups.map(&:role), :team
    assert_equal 2, dashboard(drena: there.public_id).recent_signups.size
  end

  test "an unknown DRENA gives the national view" do
    create_drena
    create_team_member

    board = dashboard(drena: "inconnue")

    assert_nil board.drena
    assert_equal 1, board.accounts.team
    assert_equal 1, board.drenas.size
  end

  test "the ten latest signups, with role, school and date, and a masked contact only" do
    school = create_school(name: "Lycée Classique d'Abidjan")
    classroom = create_classroom(school:)
    10.times { |index| create_student(created_at: (20 + index).days.ago) }
    teacher = create_teacher(school:, first_name: "Yao", last_name: "Kouadio", created_at: 2.days.ago)
    student = placed_student(classroom, first_name: "Aya", last_name: "Kouassi", contact: "0102030445", created_at: 1.day.ago)
    create_team_member(created_at: 3.days.ago)
    create_student(created_at: 1.hour.ago, anonymized_at: Time.current)

    signups = dashboard.recent_signups

    assert_equal 10, signups.size
    assert_equal Query::SignupRow.new(public_id: student.public_id, display_name: "Aya Kouassi", role: :student,
                                      school_name: "Lycée Classique d'Abidjan", contact: "01 •• •• •• 45",
                                      created_at: student.reload.created_at), signups.first
    assert_equal [ :teacher, "Lycée Classique d'Abidjan" ], signups.second.to_h.values_at(:role, :school_name)
    assert_equal [ :team, nil ], signups.third.to_h.values_at(:role, :school_name)
    assert_nil signups.last.school_name
    assert(signups.none? { it.contact.match?(/\d{3}/) })
    assert_equal teacher.public_id, signups.second.public_id
  end

  test "the number of queries does not grow with the volume" do
    seed_territory(1)
    small = count_queries { dashboard(drena: nil) }
    filtered_small = count_queries { dashboard(drena: Orm::Drena.first.public_id) }
    seed_territory(3)

    assert_equal small, count_queries { dashboard(drena: nil) }
    assert_equal filtered_small, count_queries { dashboard(drena: Orm::Drena.first.public_id) }
    assert_equal [ 18, 21 ], [ small, filtered_small ], "national, then under a DRENA filter (ADR-0062)"
  end

  private

  def seed_territory(count)
    level = Orm::Level.first || create_level
    count.times do
      school = create_school
      classroom = create_classroom(school:, level:)
      teacher = create_teacher(school:, classrooms: [ classroom ])
      2.times do
        student = create_student(classroom:)
        create_exercise_session(student:, status: "completed", score_percent: 70, completed_at: 1.hour.ago)
      end
      create_assignment(classroom:, by: teacher)
    end
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
