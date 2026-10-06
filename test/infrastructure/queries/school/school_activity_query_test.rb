require "test_helper"

# AD-17, AD-18 (UDR-0074 §3.11): the recent activity of the direction's school, read in the dated business tables
# (assignments, memberships, attachments), never in the audit log. Three kinds of event, the 10 most recent of the last
# 30 days, in the active classrooms of the year of this school only, and a fixed number of queries whatever the volume.
class Queries::School::SchoolActivityQueryTest < ActiveSupport::TestCase
  Query = Queries::School::SchoolActivityQuery

  setup do
    # A Sunday: « Hier » is Saturday 3 October, and Tuesday 29 September is five days earlier.
    travel_to Time.zone.local(2026, 10, 4, 11, 0)
    @school = create_school(name: "Lycée moderne de Cocody")
    @troisieme_2 = classroom("3ème 2", level: create_level(name: "3ème"))
    @sixieme_1 = classroom("6ème 1", level: create_level(name: "6ème"))
    @kouassi = teacher(gender: "male", first_name: "Yao", last_name: "Kouassi")
  end

  def events(school: @school) = Query.new.call(school_id: school.id, now: Time.current)

  def classroom(name, school: @school, level: create_level, **) = create_classroom(school:, level:, name:, **)

  # The factories date a teacher's attachment and a student's membership now: each scenario dates its own.
  def teacher(at: 90.days.ago, school: @school, **)
    create_teacher(school:, **).tap { Orm::TeacherSchool.where(teacher: it).update_all(created_at: at) }
  end

  def joined(classroom, at:, **)
    create_student(classroom:, **).tap { Orm::ClassroomStudent.where(student: it).update_all(joined_at: at) }
  end

  def given(classroom, at:, by: @kouassi, title: "Exercice #{factory_sequence}", **)
    create_assignment(classroom:, assignable: create_exercise(title:, questions: 0), by:, assigned_at: at, **)
  end

  def event(kind, at, **) = Query::Event.new(**Query::Event.members.to_h { [ it, nil ] }, kind:, at:, **)

  test "AD-17: an assignment, a student's arrival and a teacher's arrival, from the most recent" do
    given(@troisieme_2, at: 2.hours.ago, title: "Les fractions")
    joined(@sixieme_1, at: 1.day.ago, first_name: "Awa", last_name: "Koné")
    teacher(at: 5.days.ago, gender: "female", first_name: "Mariam", last_name: "Traoré")

    assert_equal [ event(:assignment, 2.hours.ago, teacher_gender: "male", teacher_last_name: "Kouassi", teacher_anonymized: false,
                         exercise_title: "Les fractions", classroom_name: "3ème 2", classroom_public_id: @troisieme_2.public_id),
                   event(:student_joined, 1.day.ago, student_first_name: "Awa", student_last_initial: "K", classroom_name: "6ème 1",
                                                     classroom_public_id: @sixieme_1.public_id),
                   event(:teacher_joined, 5.days.ago, teacher_gender: "female", teacher_last_name: "Traoré", teacher_anonymized: false) ],
                 events
  end

  test "AD-17: the kinds are mixed by date, the most recent first" do
    given(@troisieme_2, at: 3.hours.ago)
    joined(@sixieme_1, at: 1.hour.ago)
    teacher(at: 4.hours.ago)
    given(@troisieme_2, at: 2.hours.ago)

    assert_equal [ [ :student_joined, 1.hour.ago ], [ :assignment, 2.hours.ago ], [ :assignment, 3.hours.ago ],
                   [ :teacher_joined, 4.hours.ago ] ], events.map { [ it.kind, it.at ] }
  end

  test "AD-17: the initial of a student's last name is a capital, whatever the stored case" do
    joined(@sixieme_1, at: 1.hour.ago, first_name: "Éric", last_name: "été")

    assert_equal [ [ "Éric", "É" ] ], events.map { [ it.student_first_name, it.student_last_initial ] }
  end

  test "AD-18: at most the 10 most recent events of the school" do
    12.times do |index|
      at = (index + 1).hours.ago
      [ -> { given(@troisieme_2, at:) }, -> { joined(@sixieme_1, at:) }, -> { teacher(at:) } ][index % 3].call
    end

    assert_equal (1..10).map { it.hours.ago }, events.map(&:at)
    assert_equal %i[assignment student_joined teacher_joined] * 3 + %i[assignment], events.map(&:kind)
  end

  # Each kind is read on its own, then merged: each read must keep the most recent of its kind, not any 10 of them.
  test "AD-18: a kind alone keeps its 10 most recent events" do
    assignments, arrivals, teachers = Array.new(3) { create_school }
    given_in = classroom("3ème 1", school: assignments)
    joined_in = classroom("3ème 1", school: arrivals)
    { assignments => ->(at) { given(given_in, at:) }, arrivals => ->(at) { joined(joined_in, at:) },
      teachers => ->(at) { teacher(at:, school: teachers) } }.each do |school, add|
      [ 11, 2, 7, 1, 10, 4, 9, 3, 8, 5, 6 ].each { add.call(it.hours.ago) }

      assert_equal (1..10).map { it.hours.ago }, events(school:).map(&:at), school.name
    end
  end

  test "AD-18: the window holds the last 30 days, 30 days ago to the second included, 31 days ago and the future excluded" do
    [ 30.days.ago, 31.days.ago, 1.minute.from_now ].each do |at|
      given(@troisieme_2, at:)
      joined(@sixieme_1, at:)
      teacher(at:)
    end

    found = events

    assert_equal [ 30.days.ago ] * 3, found.map(&:at)
    assert_equal %i[assignment student_joined teacher_joined], found.map(&:kind).sort
  end

  test "AD-18: another school's assignments, arrivals and teachers never show" do
    other = create_school(name: "Lycée classique d'Abidjan")
    klass = classroom("3ème 2", school: other)
    given(klass, at: 1.hour.ago, by: teacher(school: other))
    joined(klass, at: 1.hour.ago)
    teacher(at: 1.hour.ago, school: other)

    assert_empty events
    assert_equal %i[assignment student_joined teacher_joined], events(school: other).map(&:kind).sort
  end

  test "a classroom archived or of another school year never shows" do
    [ classroom("3ème 3", status: "archived"), classroom("3ème 4", school_year: "2025-2026") ].each do |klass|
      given(klass, at: 1.hour.ago)
      joined(klass, at: 1.hour.ago)
    end

    assert_empty events
  end

  test "the school year is the one of the instant, unless given" do
    past = classroom("3ème 9", school_year: "2025-2026")
    given(past, at: 2.hours.ago)

    assert_equal [ past.public_id ],
                 Query.new.call(school_id: @school.id, now: Time.current, school_year: "2025-2026").map(&:classroom_public_id)
    assert_empty events
  end

  test "an anonymized student's arrival disappears" do
    joined(@sixieme_1, at: 1.hour.ago, anonymized_at: 1.minute.ago)

    assert_empty events
  end

  test "an anonymized teacher's assignments stay, signed by the function alone, and his arrival disappears" do
    gone = teacher(at: 1.day.ago, gender: "male", last_name: "Kouassi", anonymized_at: 1.minute.ago)
    given(@troisieme_2, at: 1.hour.ago, by: gone, title: "Les fractions")

    assert_equal [ event(:assignment, 1.hour.ago, teacher_anonymized: true, exercise_title: "Les fractions", classroom_name: "3ème 2",
                                                  classroom_public_id: @troisieme_2.public_id) ], events
  end

  test "an archived assignment, like those of a withdrawn teacher, was still given" do
    given(@troisieme_2, at: 1.hour.ago, status: "archived")

    assert_equal [ :assignment ], events.map(&:kind)
  end

  test "AD-17: at most 4 queries, whatever the volume" do
    build = lambda do |count|
      count.times do |index|
        given(index.even? ? @troisieme_2 : @sixieme_1, at: (index + 1).hours.ago)
        joined(@sixieme_1, at: (index + 1).minutes.ago)
        teacher(at: (index + 1).days.ago)
      end
    end
    build.call(1)
    small = count_queries { events }
    build.call(12)

    assert_operator small, :<=, 4
    assert_equal small, count_queries { assert_equal 10, events.size }
  end

  private

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
