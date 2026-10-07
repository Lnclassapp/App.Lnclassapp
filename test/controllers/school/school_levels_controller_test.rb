require "test_helper"

# IL-04, IL-06 (ADR-0083 §4.2, UDR-0079 §3.3): the levels of a school, public and limited to 30 requests a minute — the
# « picker_levels » frame of the student cascade. Only the levels that have an active classroom this year; never a
# classroom, a headcount nor a teacher.
class School::SchoolLevelsControllerTest < ActionDispatch::IntegrationTest
  PICKER = "classroom.student_registrations.class_picker".freeze

  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @troisieme = create_level(name: "3ème", position: 4)
    @sixieme = create_level(name: "6ème", position: 1)
    @classroom = create_classroom(school: @school, level: @troisieme, name: "3e 2")
    create_classroom(school: @school, level: @sixieme, name: "6e 1")
    create_classroom(school: @school, level: create_level(name: "2nde"), status: "archived")
  end

  def levels(school_public_id = @school.public_id, **params)
    get school_picker_levels_path(school_public_id, **params), headers: { "Turbo-Frame" => "picker_levels" }
  end

  test "IL-04: the frame lists the levels with an active classroom, in order, for a visitor" do
    levels(scope: "student_registration")

    assert_response :success
    assert_select "turbo-frame#picker_levels.block.transition-opacity[aria-live=polite]" do
      assert_select "label[for='student_registration_level_slug']", text: /#{I18n.t("#{PICKER}.level")}/
      assert_select "select[name='student_registration[level_slug]'][required]" \
                    "[data-action='change->classroom--class-picker#loadClassrooms']"
      assert_select "option[value='']", text: I18n.t("#{PICKER}.level_prompt")
      assert_equal [ "6ème", "3ème" ], css_select("option[value!='']").map(&:text)
    end
    assert_no_match(/2nde|3e 2|6e 1/, response.body)
    assert_not_includes response.body, @classroom.public_id
  end

  test "the fields follow the scope of the page: sign-up by default, or « choose your classroom »" do
    levels(scope: "student_classroom_choice")

    assert_select "select[name='student_classroom_choice[level_slug]']"

    [ "", "user", "teacher_registration" ].each do |scope|
      levels(scope:)

      assert_select "select[name='student_registration[level_slug]']", 1, scope
    end
  end

  test "IL-06: a school without an active classroom, a closed or unknown one: « not on Lnclass yet », no list" do
    closed = create_school(status: "draft")
    create_classroom(school: closed)

    [ create_school.public_id, closed.public_id, "sch-inconnu" ].each do |public_id|
      levels(public_id)

      assert_response :success
      assert_select "turbo-frame#picker_levels", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_title"))}/
      assert_select "turbo-frame#picker_levels", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_description"))}/
      assert_select "select", 0
    end
  end

  test "the 31st request of a minute from the same address receives 429, with the error state in the frame and « Retry »" do
    30.times do
      levels

      assert_response :success
    end

    levels(scope: "student_registration")

    assert_response :too_many_requests
    assert_select "turbo-frame#picker_levels [role=alert]", text: /#{Regexp.escape(I18n.t("#{PICKER}.rate_limited"))}/
    assert_select "turbo-frame#picker_levels a[href='#{school_picker_levels_path(@school.public_id, scope: 'student_registration')}']"
    assert_select "select", 0
  end
end
