require "test_helper"

# ADR-0113 §4.3 (amende ADR-0090 §4.1): opening the lesson page records, for a student, the reading of each published
# notion of the lesson. Nobody else leaves a trace, a draft notion is not read, a failed reading does not break the page,
# and a prefetch is not an opening.
class Catalog::CourseReadTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Propriétés de Thalès")
    @first = create_essential(course: @course, name: "Énoncé")
    @second = create_essential(course: @course, name: "Réciproque")
    @draft = create_essential(course: @course, name: "Brouillon", status: "draft")
    @student = create_student_for(@course)
  end

  def read_ids = Orm::EssentialRead.where(student: @student).pluck(:essential_id).sort

  test "the student opening the lesson reads each of its published notions" do
    sign_in_as @student

    get course_path(@course.slug)

    assert_response :success
    assert_equal [ @first.id, @second.id ].sort, read_ids
  end

  test "opening it again keeps one reading per notion, and moves the last opening" do
    sign_in_as @student
    get course_path(@course.slug)
    travel 1.hour do
      get course_path(@course.slug)
    end

    assert_equal 2, Orm::EssentialRead.where(student: @student).count
    assert_operator Orm::EssentialRead.find_by!(student: @student, essential: @first).last_read_at, :>,
                    Orm::EssentialRead.find_by!(student: @student, essential: @first).first_read_at
  end

  test "a teacher and the team leave no reading" do
    [ create_teacher, create_team_member ].each do |user|
      sign_in_as user
      get course_path(@course.slug)
      assert_response :success
      sign_out
    end

    assert_equal 0, Orm::EssentialRead.count
  end

  test "a student of another level is refused and reads nothing" do
    sign_in_as create_student(classroom: create_classroom(level: create_level(name: "Tle")))

    get course_path(@course.slug)

    assert_response :not_found
    assert_equal 0, Orm::EssentialRead.count
  end

  test "a prefetch is not an opening" do
    sign_in_as @student

    get course_path(@course.slug), headers: { "X-Sec-Purpose" => "prefetch" }

    assert_equal 0, Orm::EssentialRead.count
  end

  test "a storage outage while reading is reported, and the page is shown all the same" do
    sign_in_as @student
    reports = []
    subscriber = Class.new { define_method(:report) { |error, **| reports << error } }.new
    Rails.error.subscribe(subscriber)
    failing = ->(**) { raise ActiveRecord::ConnectionNotEstablished }

    stub_any_instance(Repositories::Assessment::EssentialReadRepository, :record, failing) do
      get course_path(@course.slug)
    end

    assert_response :success
    assert_not_empty reports
  ensure
    Rails.error.unsubscribe(subscriber)
  end
end
