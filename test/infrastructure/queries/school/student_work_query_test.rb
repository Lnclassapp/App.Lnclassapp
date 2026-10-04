require "test_helper"

# DS-07, DS-08, DS-09, DS-10 (ADR-0065 §4): « Travail des élèves » of the school management reads live figures. Every
# definition of the ADR has its own test, another school never shows, and the number of queries does not follow the volume.
class Queries::School::StudentWorkQueryTest < ActiveSupport::TestCase
  Query = Queries::School::StudentWorkQuery

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @seconde = create_level(name: "2nde", position: 5)
    @terminale = create_level(name: "Tle", position: 7)
    @teacher = create_teacher(school: @school)
    @exercise = create_exercise
  end

  def overview(school: @school) = Query.new.classrooms(school_id: school.id)
  def detail(classroom, school: @school) = Query.new.classroom(school_id: school.id, public_id: classroom.public_id)
  def row_of(classroom, school: @school) = overview(school:).classrooms.find { it.public_id == classroom.public_id }

  def classroom(name: "2nde C 1", level: @seconde, school: @school, **) = create_classroom(school:, level:, name:, **)
  def assignment(classroom, **) = create_assignment(classroom:, assignable: create_exercise, by: @teacher, **)

  # A submitted assignment: a completed standard session tied to it (ADR-0065 §4).
  def submit(student, assignment, score, **)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: score,
                            classroom_assignment_id: assignment.id, **)
  end

  # DS-07 and DS-09: 4 students, 2 assignments; A hands in both (80, 60), B one (70), C and D none; B's remediation at 100.
  def seconde_c1
    klass = classroom
    first, second = assignment(klass), assignment(klass)
    a = create_student(classroom: klass, first_name: "Aya", last_name: "Bamba")
    b = create_student(classroom: klass, first_name: "Moussa", last_name: "Coulibaly")
    create_student(classroom: klass, first_name: "Fanta", last_name: "Diabaté")
    create_student(classroom: klass, first_name: "Koffi", last_name: "Diallo")
    submit(a, first, 80)
    submit(a, second, 60)
    submit(b, first, 70)
    create_exercise_session(student: b, exercise: @exercise, status: "completed", score_percent: 100,
                            gap: create_gap(student: b), classroom_assignment_id: first.id)
    [ klass, a, b ]
  end

  test "DS-07: the classroom row counts students, assignments, the submission rate, and hides the average under 5" do
    klass, = seconde_c1

    row = row_of(klass)

    assert_equal Query::ClassroomRow.new(public_id: klass.public_id, name: "2nde C 1", level_name: "2nde", level_slug: "2nde",
                                         students_count: 4, assignments_count: 2, submitted_count: 3, submission_rate: 38,
                                         average_percent: nil), row
  end

  test "the overview names the school and the school year, and keeps only the active classrooms of the year" do
    kept = classroom
    classroom(name: "2nde C 2", status: "archived")
    classroom(name: "2nde C 3", school_year: "2020-2021")

    board = overview

    assert_equal "Lycée Moderne de Bouaké", board.school_name
    assert_equal Entities::Classroom::SchoolYear.current(Date.current), board.school_year
    assert_equal [ kept.public_id ], board.classrooms.map(&:public_id)
  end

  test "classrooms are sorted by level position, then by name" do
    classroom(name: "Tle D 2", level: @terminale)
    classroom(name: "2nde C 2")
    classroom(name: "2nde A 1")

    assert_equal [ "2nde A 1", "2nde C 2", "Tle D 2" ], overview.classrooms.map(&:name)
  end

  test "an empty school has no classroom; a classroom without student or assignment has no rate and no average" do
    assert_empty overview.classrooms

    empty = classroom
    lonely = classroom(name: "2nde C 2")
    create_student(classroom: lonely)
    unfollowed = classroom(name: "2nde C 3")
    assignment(unfollowed)

    assert_equal [ 0, 0, 0, nil, nil ],
                 row_of(empty).to_h.values_at(:students_count, :assignments_count, :submitted_count, :submission_rate, :average_percent)
    assert_equal [ 1, 0, nil ], row_of(lonely).to_h.values_at(:students_count, :assignments_count, :submission_rate)
    assert_equal [ 0, 1, nil ], row_of(unfollowed).to_h.values_at(:students_count, :assignments_count, :submission_rate)
  end

  test "an assignment is given whatever its status, and an archived one still counts as handed in" do
    klass = classroom
    archived = assignment(klass, status: "archived")
    submit(create_student(classroom: klass), archived, 50)

    assert_equal [ 1, 1, 100 ], row_of(klass).to_h.values_at(:students_count, :assignments_count, :submission_rate)
  end

  test "a student who left or whose account is anonymized is neither counted nor read in the figures" do
    klass = classroom
    given = assignment(klass)
    present = create_student(classroom: klass)
    submit(present, given, 40)
    gone = create_student(classroom: klass)
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    submit(gone, given, 100)
    submit(create_student(classroom: klass, anonymized_at: Time.current), given, 100)

    assert_equal [ 1, 100 ], row_of(klass).to_h.values_at(:students_count, :submission_rate)
    assert_equal [ 1 ], detail(klass).students.map(&:submitted_count)
  end

  test "a session is handed in only if completed, standard, tied to an assignment of the classroom and by one of its students" do
    klass = classroom
    given = assignment(klass)
    student = create_student(classroom: klass)
    create_exercise_session(student:, exercise: @exercise, status: "started", classroom_assignment_id: given.id)
    create_exercise_session(student:, exercise: @exercise, status: "abandoned", classroom_assignment_id: given.id)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 90)
    submit(student, assignment(classroom(name: "2nde C 2")), 90)

    assert_equal 0, row_of(klass).submission_rate
    assert_equal [ 0, nil ], detail(klass).students.map { [ it.submitted_count, it.average_percent ] }.first
  end

  test "an assignment handed in twice counts once in the rate, but both sessions count in the averages" do
    klass = classroom
    given = assignment(klass)
    student = create_student(classroom: klass)
    submit(student, given, 40)
    submit(student, given, 70)

    assert_equal 100, row_of(klass).submission_rate
    assert_equal [ 1, 55 ], detail(klass).students.map { [ it.submitted_count, it.average_percent ] }.first
  end

  # Non-regression of the definitions (chantier cache-ecrans-lourds, lot 1): a student in two classrooms hands in each
  # assignment for its own classroom only, and only while present in it; the sessions are read from the assignment.
  test "a student in two classrooms counts only in the classroom of the assignment, and only while present in it" do
    first, second = classroom, classroom(name: "2nde C 2")
    first_assignment, second_assignment = assignment(first), assignment(second)
    both = create_student(classroom: first, first_name: "Awa", last_name: "Koné")
    Orm::ClassroomStudent.create!(classroom: second, student: both, primary: false, joined_at: Time.current)
    submit(both, first_assignment, 40)
    submit(both, second_assignment, 80)
    submit(both, second_assignment, 60)
    left = create_student(classroom: first, first_name: "Yao", last_name: "Kouassi")
    Orm::ClassroomStudent.create!(classroom: second, student: left, primary: false, joined_at: Time.current, left_at: Time.current)
    submit(left, second_assignment, 100)
    submit(left, first_assignment, 20)

    assert_equal [ 2, 1, 100 ], row_of(first).to_h.values_at(:students_count, :assignments_count, :submission_rate)
    assert_equal [ 1, 1, 100 ], row_of(second).to_h.values_at(:students_count, :assignments_count, :submission_rate)
    assert_equal [ [ "Awa Koné", 1, 40 ], [ "Yao Kouassi", 1, 20 ] ],
                 detail(first).students.map { [ it.display_name, it.submitted_count, it.average_percent ] }
    assert_equal [ [ "Awa Koné", 1, 70 ] ], detail(second).students.map { [ it.display_name, it.submitted_count, it.average_percent ] }
  end

  test "DS-08: the classroom average shows from 5 students having handed in, over all their sessions" do
    klass = classroom
    given = assignment(klass)
    students = [ 50, 60, 70, 80 ].map { |score| create_student(classroom: klass).tap { submit(it, given, score) } }
    submit(students.first, assignment(klass), 50)

    assert_nil row_of(klass).average_percent, "4 students having handed in: « — »"

    submit(create_student(classroom: klass), given, 90)

    assert_equal Query::MIN_STUDENTS_FOR_AVERAGE, 5
    assert_equal 67, row_of(klass).average_percent, "(50 + 50 + 60 + 70 + 80 + 90) / 6, rounded"
    assert_equal 67, detail(klass).classroom.average_percent
  end

  test "DS-08: 5 students at 50, 60, 70, 80 and 90 % average 70 %" do
    klass = classroom
    given = assignment(klass)
    [ 50, 60, 70, 80, 90 ].each { |score| submit(create_student(classroom: klass), given, score) }

    assert_equal 70, row_of(klass).average_percent
  end

  test "DS-09: the classroom detail lists each present student, handed in over given, and their rounded average" do
    klass, = seconde_c1
    gone = create_student(classroom: klass, first_name: "Awa", last_name: "Adou")
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    create_student(classroom: klass, first_name: "Awa", last_name: "Aka", anonymized_at: Time.current)

    found = detail(klass)

    assert_equal row_of(klass), found.classroom
    assert_equal [ Query::StudentRow.new(display_name: "Aya Bamba", submitted_count: 2, average_percent: 70),
                   Query::StudentRow.new(display_name: "Moussa Coulibaly", submitted_count: 1, average_percent: 70),
                   Query::StudentRow.new(display_name: "Fanta Diabaté", submitted_count: 0, average_percent: nil),
                   Query::StudentRow.new(display_name: "Koffi Diallo", submitted_count: 0, average_percent: nil) ], found.students
  end

  test "a student's average is rounded, a classroom without student lists nobody" do
    klass = classroom
    given = assignment(klass)
    student = create_student(classroom: klass)
    submit(student, given, 66)
    submit(student, assignment(klass), 67)

    assert_equal 67, detail(klass).students.first.average_percent
    assert_empty detail(classroom(name: "2nde C 2")).students
  end

  test "DS-10: another school's classrooms and students never show, and its classroom page is nil" do
    seconde_c1
    other_school = create_school(name: "Lycée Classique d'Abidjan")
    other = classroom(name: "Tle D 1", school: other_school)
    submit(create_student(classroom: other, first_name: "Intrus"), assignment(other), 100)

    assert_equal [ "2nde C 1" ], overview.classrooms.map(&:name)
    assert_nil detail(other)
    assert_equal [ "Tle D 1" ], overview(school: other_school).classrooms.map(&:name)
  end

  test "an unknown, archived or past classroom of the school has no page" do
    assert_nil Query.new.classroom(school_id: @school.id, public_id: "inconnu")
    assert_nil detail(classroom(name: "2nde C 2", status: "archived"))
    assert_nil detail(classroom(name: "2nde C 3", school_year: "2020-2021"))
  end

  # AD-09, AD-10 (UDR-0072 §3.8): a level's page reads the active classrooms of the year of that level, in this school
  # only, with the same rows as the home page.
  test "AD-09: a level lists its active classrooms of the year, sorted by name, with the same rows" do
    klass, = seconde_c1
    second = classroom(name: "2nde A 2")
    classroom(name: "Tle D 1", level: @terminale)

    level = Query.new.level(school_id: @school.id, slug: "2nde")

    assert_equal Query::LevelOverview.new(level_name: "2nde", level_slug: "2nde", classrooms: [ row_of(second), row_of(klass) ]), level
  end

  test "AD-10: another school's, archived or past classrooms of the level never show" do
    kept = classroom
    classroom(name: "2nde C 2", status: "archived")
    classroom(name: "2nde C 3", school_year: "2020-2021")
    classroom(name: "2nde C 4", school: create_school(name: "Lycée Classique d'Abidjan"))

    assert_equal [ kept.public_id ], Query.new.level(school_id: @school.id, slug: "2nde").classrooms.map(&:public_id)
  end

  test "AD-11: an unknown level, or a level without an active classroom of the school this year, has no page" do
    classroom(name: "Tle D 1", level: @terminale, school: create_school(name: "Lycée Classique d'Abidjan"))
    classroom(name: "Tle D 2", level: @terminale, status: "archived")

    assert_nil Query.new.level(school_id: @school.id, slug: "7eme")
    assert_nil Query.new.level(school_id: @school.id, slug: "tle")
    assert_nil Query.new.level(school_id: @school.id, slug: nil)
  end

  test "the number of queries does not follow the volume" do
    build = lambda do |count|
      count.times do |index|
        klass = classroom(name: "C#{factory_sequence}", level: index.even? ? @seconde : @terminale)
        given = assignment(klass)
        2.times { submit(create_student(classroom: klass), given, 50) }
      end
    end
    build.call(1)
    small = count_queries { overview }
    small_detail = count_queries { detail(Orm::Classroom.first) }
    small_level = count_queries { Query.new.level(school_id: @school.id, slug: "2nde") }
    build.call(3)

    assert_equal small, count_queries { overview }
    assert_equal small_detail, count_queries { detail(Orm::Classroom.last) }
    assert_equal small_level, count_queries { Query.new.level(school_id: @school.id, slug: "2nde") }
  end

  private

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
