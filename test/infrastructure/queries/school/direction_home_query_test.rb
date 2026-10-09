require "test_helper"

# AD-02 to AD-08 (UDR-0074 §3.2): the direction's home reads its school card and its level bubbles. Its figures reuse the
# definitions of « Travail des élèves » (ADR-0065) and of the « Enseignants » page, and the number of queries is fixed.
class Queries::School::DirectionHomeQueryTest < ActiveSupport::TestCase
  Query = Queries::School::DirectionHomeQuery
  Alert = Entities::School::DirectionAlerts::Alert

  setup do
    @school = create_school(name: "Lycée Moderne de Cocody", school_type: "private")
    @sixth = create_level(name: "6ème", position: 1)
    @fifth = create_level(name: "5ème", position: 2)
    @third = create_level(name: "3ème", position: 4)
    @final = create_level(name: "Tle", position: 7)
    @teacher = create_teacher(school: @school, first_name: "Yao", last_name: "Kouassi")
    @exercise = create_exercise
  end

  # Les définitions se lisent en direct ; le cache de 5 minutes a ses propres tests, plus bas (AD-23).
  def home(school: @school, cache: ActiveSupport::Cache::NullStore.new) = Query.new(cache:).call(school_id: school.id)

  def classroom(name, level: @third, school: @school, taught: true, **)
    create_classroom(school:, level:, name:, **).tap do |klass|
      Orm::TeacherClassroom.create!(teacher: @teacher, classroom: klass) if taught
    end
  end

  def assignment(klass) = create_assignment(classroom: klass, by: @teacher)

  def submit(student, assignment)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 50,
                            classroom_assignment_id: assignment.id)
  end

  # Students of a classroom, each handing in the first `handed` assignments given.
  def fill(klass, students:, assignments:, handed: [])
    given = Array.new(assignments) { assignment(klass) }
    Array.new(students) { |index| create_student(classroom: klass).tap { |student| given.first(handed.fetch(index, 0)).each { submit(student, it) } } }
  end

  test "AD-02: the card names the school, its type and the school year" do
    found = home

    assert_equal [ "Lycée Moderne de Cocody", "private", true, Entities::Classroom::SchoolYear.current(Date.current) ],
                 found.to_h.values_at(:school_name, :school_type, :school_active, :school_year)
  end

  test "AD-02: 3 active classrooms of the year, each present student once, and as many teachers as the « Enseignants » page" do
    first, second, third = classroom("3ème 1"), classroom("3ème 2"), classroom("6ème 1", level: @sixth)
    classroom("3ème 9", status: "archived")
    classroom("3ème 8", school_year: "2020-2021")
    both = create_student(classroom: first)
    Orm::ClassroomStudent.create!(joined_via: "standard", classroom: second, student: both, primary: false, joined_at: Time.current)
    create_student(classroom: second)
    create_student(classroom: third)
    gone = create_student(classroom: third)
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    create_student(classroom: third, anonymized_at: Time.current)
    create_student(classroom: classroom("Tle D 1", level: @final, school: create_school))
    create_teacher(school: @school, first_name: "Awa", last_name: "Koné")
    create_teacher(school: @school, last_name: "Anonyme").update!(anonymized_at: Time.current)
    create_teacher(school: create_school, last_name: "Ailleurs")

    figures = home.figures

    assert_equal Query::Figures.new(classrooms: 3, students: 3, teachers: 2), figures
    assert_equal Queries::School::SchoolTeachersQuery.new.call(school_id: @school.id).teachers.size, figures.teachers
  end

  test "AD-08: a school without an active classroom this year counts zeros and has no level" do
    classroom("3ème 9", status: "archived")
    create_teacher(school: @school, first_name: "Awa")

    found = home

    assert_equal Query::Figures.new(classrooms: 0, students: 0, teachers: 2), found.figures
    assert_empty found.levels
    assert_equal [ Alert.new(kind: :teachers_without_classroom, names: [], others: 0, count: 2) ], found.alerts
  end

  test "AD-03: the alerts read the classrooms in order (level, then name): without teacher, without students, red, idle teachers" do
    fill(classroom("6ème 2", level: @sixth, taught: false), students: 1, assignments: 0)
    classroom("3ème 3")
    fill(classroom("3ème 2"), students: 10, assignments: 1, handed: [ 1, 1, 1 ])
    fill(classroom("3ème 1"), students: 10, assignments: 1, handed: Array.new(4, 1))
    fill(classroom("Tle D 1", level: @final, taught: false), students: 2, assignments: 2, handed: [ 2, 2 ])
    create_teacher(school: @school, first_name: "Awa")

    assert_equal [ Alert.new(kind: :without_teacher, names: [ "6ème 2", "Tle D 1" ], others: 0, count: 2),
                   Alert.new(kind: :without_students, names: [ "3ème 3" ], others: 0, count: 1),
                   Alert.new(kind: :red_signal, names: [ "3ème 2" ], others: 0, count: 1),
                   Alert.new(kind: :teachers_without_classroom, names: [], others: 0, count: 1) ], home.alerts
  end

  test "AD-03: a classroom taught only by an anonymized teacher, or by a teacher of another classroom, has no teacher" do
    taught = classroom("3ème 1")
    fill(taught, students: 1, assignments: 0)
    fill(classroom("3ème 2", taught: false), students: 1, assignments: 0)
    alone = classroom("3ème 3", taught: false)
    fill(alone, students: 1, assignments: 0)
    create_teacher(school: @school, classrooms: [ alone ]).update!(anonymized_at: Time.current)

    assert_equal [ Alert.new(kind: :without_teacher, names: [ "3ème 2", "3ème 3" ], others: 0, count: 2) ], home.alerts
  end

  test "AD-04: an inactive school, or one still in draft, alerts first; an active one does not" do
    { "inactive" => false, "draft" => false, "active" => true }.each do |status, active|
      @school.update!(status:)

      found = home

      assert_equal active, found.school_active, status
      assert_equal [ (:inactive unless active), :teachers_without_classroom ].compact, found.alerts.map(&:kind), status
    end
  end

  test "AD-06: one bubble per level with an active classroom of the year, by level position, series together" do
    final_c = create_series(name: "C")
    final_d = create_series(name: "D")
    classroom("Tle D 1", level: @final, series: final_d)
    classroom("Tle C 1", level: @final, series: final_c)
    classroom("3ème 1")
    classroom("6ème 1", level: @sixth)
    classroom("5ème 1", level: @fifth, status: "archived")
    classroom("5ème 2", level: @fifth, school: create_school)

    assert_equal [ Query::LevelBubble.new(slug: "6eme", name: "6ème", classrooms_count: 1, submission_rate: nil),
                   Query::LevelBubble.new(slug: "3eme", name: "3ème", classrooms_count: 1, submission_rate: nil),
                   Query::LevelBubble.new(slug: "tle", name: "Tle", classrooms_count: 2, submission_rate: nil) ], home.levels
  end

  test "AD-07: a level's rate sums its classrooms: Σ handed in × 100 / Σ (students × assignments), rounded" do
    fill(classroom("3ème 1"), students: 2, assignments: 2, handed: [ 2, 1 ])
    fill(classroom("3ème 2"), students: 2, assignments: 1, handed: [ 1 ])
    fill(classroom("3ème 3"), students: 0, assignments: 3)
    fill(classroom("3ème 4"), students: 4, assignments: 0)

    level = home.levels.sole

    assert_equal [ 4, 67 ], [ level.classrooms_count, level.submission_rate ], "4 handed in of 6 expected, not the mean of 75 and 50 %"
  end

  test "AD-07: a level whose classrooms have no student or no assignment has no rate" do
    fill(classroom("3ème 1"), students: 0, assignments: 2)
    fill(classroom("3ème 2"), students: 3, assignments: 0)
    fill(classroom("6ème 1", level: @sixth), students: 1, assignments: 1, handed: [ 1 ])

    assert_equal [ 100, nil ], home.levels.map(&:submission_rate)
  end

  test "another school's figures, alerts and levels never show" do
    other = create_school(name: "Lycée Classique d'Abidjan", status: "inactive")
    fill(classroom("Tle D 9", level: @final, school: other, taught: false), students: 2, assignments: 1)
    create_teacher(school: other)

    found = home

    assert_equal [ Query::Figures.new(classrooms: 0, students: 0, teachers: 1), [], [ :teachers_without_classroom ] ],
                 [ found.figures, found.levels, found.alerts.map(&:kind) ]
    assert_equal "Lycée Classique d'Abidjan", home(school: other).school_name
  end

  test "the number of queries does not follow the number of classrooms, and stays within 12" do
    build = lambda do |count|
      count.times do |index|
        fill(classroom("C#{factory_sequence}", level: index.even? ? @third : @sixth, taught: index.odd?),
             students: 2, assignments: 1, handed: [ 1 ])
      end
    end
    build.call(1)
    small = count_queries { home }
    build.call(3)

    assert_equal small, count_queries { home }
    assert_operator small, :<=, 12
  end

  # AD-23 (ADR-0065, amendement du 2026-10-04 ; budget de l'ADR-0067) : l'accueil garde ses chiffres, ses alertes et ses
  # bulles 5 minutes par établissement et par année scolaire, comme le pilotage de l'équipe garde son année.
  test "AD-23: the home gives the same figures cold, warm and without a cache" do
    fill(classroom("3ème 1"), students: 2, assignments: 1, handed: [ 1 ])
    cache = ActiveSupport::Cache::MemoryStore.new
    live = home

    assert_equal live, home(cache:), "cold entry"
    assert_equal live, home(cache:), "warm entry"
  end

  test "AD-23: a second read within 5 minutes runs no query; the figures are late at 4 min 59 s, fresh at 5 min 01 s" do
    fill(classroom("3ème 1"), students: 2, assignments: 1, handed: [ 1 ])
    cache = ActiveSupport::Cache::MemoryStore.new
    # The cache counts its 5 minutes from the write, at the end of the first read: the clock is frozen so that this read,
    # however slow on a loaded machine, writes its entry at read_at (chantier tests-instables-cache-blog).
    freeze_time
    read_at = Time.current
    home(cache:)

    assert_equal 0, count_queries { home(cache:) }

    fill(classroom("3ème 2"), students: 1, assignments: 0)
    travel_to(read_at + 4.minutes + 59.seconds) { assert_equal 1, home(cache:).figures.classrooms }
    travel_to(read_at + 5.minutes + 1.second) { assert_equal 2, home(cache:).figures.classrooms }
  end

  test "AD-23: two schools never share an entry" do
    other = create_school(name: "Lycée Classique d'Abidjan")
    classroom("3ème 1")
    cache = ActiveSupport::Cache::MemoryStore.new

    assert_equal "Lycée Moderne de Cocody", home(cache:).school_name
    assert_equal [ "Lycée Classique d'Abidjan", 0 ], home(school: other, cache:).then { [ it.school_name, it.figures.classrooms ] }
  end

  test "AD-23: by default, the home reads through Rails.cache" do
    classroom("3ème 1")
    Query.new.call(school_id: @school.id)

    assert_equal 0, count_queries { Query.new.call(school_id: @school.id) }
  end

  private

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
