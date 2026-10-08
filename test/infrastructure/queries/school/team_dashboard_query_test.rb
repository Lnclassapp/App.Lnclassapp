require "test_helper"

# TR-10, TR-12 (ADR-0062, UDR-0049): the team dashboard reads aggregated indicators straight from the business tables.
# The old « Control Center » had no test at all and broke on a renamed method; here every definition of ADR-0062 §4
# has its own test, and the number of queries is checked against the volume.
class Queries::School::TeamDashboardQueryTest < ActiveSupport::TestCase
  Period = Entities::School::ReportingPeriod
  Query = Queries::School::TeamDashboardQuery

  def dashboard(period: "7d", drena: nil, cache: Rails.cache)
    Query.new(cache:).call(period: Period.parse(period, today: Date.current), drena_public_id: drena)
  end

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
    assert_equal Query::AppOpeners.new(students: 0, teachers: 0, android_students: 0), board.app_openers
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
    # La période « 30 j » part de minuit, 29 jours avant aujourd'hui, et non de l'heure d'il y a 30 jours : le 1er octobre,
    # un compte du 1er septembre à 1 h en sort.
    in_month = student.created_at >= Period.parse("30d", today: Date.current).since.in_time_zone
    assert_equal in_month ? 1 : 0, dashboard(period: "30d").signups_count
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

  # CA-11 (ADR-0082 §4.4): accounts that opened Lnclass from the installed app's icon during the period, by role.
  test "app openers count the students and teachers who opened the installed app in the period, never the anonymized" do
    since = Period.parse("7d", today: Date.current).since.in_time_zone
    3.times { create_student(app_opened_at: 1.day.ago) }
    create_student(app_opened_at: since)
    create_student(app_opened_at: since - 1.second)
    create_student(app_opened_at: 2.days.ago, anonymized_at: Time.current)
    create_student
    create_teacher(app_opened_at: 3.days.ago)
    create_team_member.update!(app_opened_at: 1.hour.ago)

    assert_equal Query::AppOpeners.new(students: 4, teachers: 1, android_students: 0), dashboard.app_openers
    assert_equal Query::AppOpeners.new(students: 5, teachers: 1, android_students: 0), dashboard(period: "30d").app_openers
  end

  # CA-6 (ADR-0084 §4.6): the students who opened the Android app in the period, a part of the students who opened an
  # installed app; an account opened from both counts once.
  test "app openers count the students who opened the Android app in the period, within the installed app's students" do
    since = Period.parse("7d", today: Date.current).since.in_time_zone
    create_student(android_opened_at: 1.day.ago)
    create_student(android_opened_at: since, app_opened_at: 2.days.ago)
    create_student(android_opened_at: since - 1.second)
    create_student(android_opened_at: 1.day.ago, anonymized_at: Time.current)
    create_student(app_opened_at: 1.day.ago, android_opened_at: 20.days.ago)
    create_teacher(app_opened_at: 3.days.ago)

    assert_equal Query::AppOpeners.new(students: 3, teachers: 1, android_students: 2), dashboard.app_openers
    assert_equal Query::AppOpeners.new(students: 4, teachers: 1, android_students: 4), dashboard(period: "30d").app_openers
  end

  test "under a DRENA filter, app openers are the territory's placed students and attached teachers" do
    here, there = create_drena(name: "Abidjan 1"), create_drena(name: "Bouaké")
    [ here, there ].each do |drena|
      school = create_school(drena:)
      classroom = create_classroom(school:)
      placed_student(classroom, app_opened_at: 1.day.ago)
      create_teacher(school:, classrooms: [ classroom ], app_opened_at: 1.day.ago)
    end
    create_student(app_opened_at: 1.day.ago)

    placed_student(create_classroom(school: create_school(drena: here)), android_opened_at: 1.day.ago)
    create_student(android_opened_at: 1.day.ago)

    assert_equal Query::AppOpeners.new(students: 2, teachers: 1, android_students: 1), dashboard(drena: here.public_id).app_openers
    assert_equal Query::AppOpeners.new(students: 5, teachers: 2, android_students: 2), dashboard.app_openers
  end

  # Non-regression of the placement definition (chantier cache-ecrans-lourds, lot 2): the total, the levels, the DRENA
  # rows, their active students and the DRENA filter all read the same placed students, whatever the edge case.
  test "placed students agree across the total, the levels, the DRENA rows and the filter, on every edge case" do
    first, second = create_level(name: "6ème", position: 1), create_level(name: "5ème", position: 2)
    here, there = create_drena(name: "Abidjan 1"), create_drena(name: "Bouaké")
    here_school, there_school = create_school(drena: here), create_school(drena: there)
    first_class, second_class = create_classroom(school: here_school, level: first), create_classroom(school: here_school, level: second)
    there_class = create_classroom(school: there_school, level: second)
    placed_student(first_class).tap { create_exercise_session(student: it, started_at: 1.day.ago) }
    placed_student(second_class).tap { create_exercise_session(student: it, started_at: 40.days.ago) }
    twice = placed_student(first_class).tap { create_exercise_session(student: it, started_at: 2.days.ago) }
    Orm::ClassroomStudent.create!(classroom: there_class, student: twice, primary: false, joined_at: Time.current)
    create_student.tap { Orm::ClassroomStudent.create!(classroom: first_class, student: it, primary: false, joined_at: Time.current) }
    placed_student(create_classroom(school: here_school, level: first, status: "archived"))
    placed_student(create_classroom(school: here_school, level: first, school_year: "2020-2021"))
    placed_student(first_class, anonymized_at: Time.current).tap { create_exercise_session(student: it, started_at: 1.day.ago) }
    placed_student(first_class).tap { Orm::ClassroomStudent.where(student: it).update_all(left_at: Time.current) }
    placed_student(there_class).tap { create_exercise_session(student: it, started_at: 3.days.ago) }
    create_student.tap { create_exercise_session(student: it, started_at: 1.day.ago) }

    board = dashboard

    assert_equal [ 4, 5 ], board.to_h.values_at(:placed_students_count, :unplaced_students_count)
    assert_equal [ 2, 2 ], levels_of(board, first, second)
    assert_equal [ [ "Abidjan 1", 3, 2 ], [ "Bouaké", 1, 1 ] ], board.drenas.map { [ it.name, it.students_count, it.active_students_count ] }
    assert_equal 4, board.active_students_count

    filtered = dashboard(drena: here.public_id)

    assert_equal [ 3, nil, 2 ], filtered.to_h.values_at(:placed_students_count, :unplaced_students_count, :active_students_count)
    assert_equal 3, filtered.accounts.students
    assert_equal [ 2, 1 ], levels_of(filtered, first, second)
    assert_equal [ [ "Abidjan 1", 3, 2 ] ], filtered.drenas.map { [ it.name, it.students_count, it.active_students_count ] }
    assert_equal [ [ "Bouaké", 1, 1 ] ], dashboard(drena: there.public_id).drenas.map { [ it.name, it.students_count, it.active_students_count ] }
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

  # ADR-0062, amendement du 2026-09-29 (cache de la vue « année ») : the school-year figures are kept 5 minutes, per
  # school year, start of period and DRENA; the latest signups stay live; 7 days and 30 days are never cached.
  def a_year_session(student, score) = create_exercise_session(student:, exercise: an_exercise, status: "completed",
                                                                score_percent: score, completed_at: 1.hour.ago)

  def sql_during(&)
    statements = []
    recorder = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record", &)
    statements
  end

  test "the year view gives the same figures with and without the cache, from a cold or a warm entry" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      a_year_session(placed_student(create_classroom), 80)
      live = dashboard(period: "year", cache: ActiveSupport::Cache::NullStore.new)

      assert_equal live, dashboard(period: "year"), "cold"
      assert_equal live, dashboard(period: "year"), "warm"
      assert_equal 1, live.completed_sessions_count
    end
  end

  test "a second year read within 5 minutes runs none of the figure queries, only the latest signups" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      a_year_session(placed_student(create_classroom), 80)
      cold = sql_during { dashboard(period: "year") }
      warm = sql_during { dashboard(period: "year") }

      assert(cold.any? { it.include?("exercise_sessions") })
      assert_empty warm.grep(/exercise_sessions|classroom_assignments|GROUP BY/)
      assert_operator warm.size, :<=, 3, warm.join("\n")
    end
  end

  test "the year figures are at most 5 minutes late, and the latest signups are never late" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      student = placed_student(create_classroom)
      a_year_session(student, 80)
      dashboard(period: "year")
      a_year_session(student, 40)
      newcomer = create_student(first_name: "Awa", last_name: "Koné")

      travel 5.minutes - 1.second
      board = dashboard(period: "year")

      assert_equal [ 1, 80 ], board.to_h.values_at(:completed_sessions_count, :average_score)
      assert_equal "Awa Koné", board.recent_signups.first.display_name
      assert_equal newcomer.public_id, board.recent_signups.first.public_id

      travel 2.seconds

      assert_equal [ 2, 60 ], dashboard(period: "year").to_h.values_at(:completed_sessions_count, :average_score)
    end
  end

  test "two DRENA filters, or a filter and the national view, never share a year entry" do
    travel_to Time.zone.local(2026, 10, 15, 12) do
      here, there = create_drena(name: "Abidjan 1"), create_drena(name: "Bouaké")
      2.times { a_year_session(placed_student(create_classroom(school: create_school(drena: here))), 90) }
      a_year_session(placed_student(create_classroom(school: create_school(drena: there))), 30)

      national = dashboard(period: "year")
      filtered_here = dashboard(period: "year", drena: here.public_id)
      filtered_there = dashboard(period: "year", drena: there.public_id)

      assert_equal [ 3, 2, 1 ], [ national, filtered_here, filtered_there ].map(&:completed_sessions_count)
      assert_equal [ 70, 90, 30 ], [ national, filtered_here, filtered_there ].map(&:average_score)
      assert_equal [ nil, "Abidjan 1", "Bouaké" ], [ national, filtered_here, filtered_there ].map { it.drena&.name }
      assert_equal national, dashboard(period: "year", drena: "inconnue").with(drena: nil), "an unknown DRENA reads the national entry"
    end
  end

  test "7 days and 30 days are read live, every time" do
    a_year_session(placed_student(create_classroom), 80)
    %w[7d 30d].each do |period|
      dashboard(period:)

      assert(sql_during { dashboard(period:) }.any? { it.include?("exercise_sessions") }, period)
    end
  end

  test "the number of queries does not grow with the volume" do
    seed_territory(1)
    small = count_queries { dashboard(drena: nil) }
    filtered_small = count_queries { dashboard(drena: Orm::Drena.first.public_id) }
    seed_territory(3)

    assert_equal small, count_queries { dashboard(drena: nil) }
    assert_equal filtered_small, count_queries { dashboard(drena: Orm::Drena.first.public_id) }
    # ADR-0082 §4.4: one grouped query more for the app openers (16 and 19 before); ADR-0084 §4.6: the Android part is
    # read by that same query.
    assert_equal [ 17, 20 ], [ small, filtered_small ], "national, then under a DRENA filter with its school rows (ADR-0062)"
  end

  private

  def levels_of(board, *levels) = levels.map { |level| board.levels.find { it.slug == level.slug }.students_count }

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
