require "test_helper"

# IL-04, IL-05, IL-06 (ADR-0083 §4.2, UDR-0079 §3.3): the classrooms of a level, public and limited to 30 requests a
# minute — the « picker_classrooms » frame of the student cascade. One radio per active classroom; a full one disabled,
# with « Complète » in its label; never a headcount, a ceiling, a teacher, a student nor a link token.
class School::LevelClassroomsControllerTest < ActionDispatch::IntegrationTest
  PICKER = "classroom.student_registrations.class_picker".freeze

  setup do
    @school = create_school(name: "Lycée Moderne de Cocody")
    @level = create_level(name: "3ème")
    @deux = create_classroom(school: @school, level: @level, name: "3e 2")
    @un = create_classroom(school: @school, level: @level, name: "3e 1", max_students: 1)
    create_classroom(school: @school, level: @level, name: "3e 3", status: "archived")
  end

  def classrooms(school_public_id = @school.public_id, level_slug = @level.slug, **params)
    get school_picker_classrooms_path(school_public_id, level_slug, **params), headers: { "Turbo-Frame" => "picker_classrooms" }
  end

  test "IL-04: the frame lists the active classrooms of the level as radios, each line a whole tap target" do
    classrooms(scope: "student_registration")

    assert_response :success
    assert_select "turbo-frame#picker_classrooms.block.transition-opacity[aria-live=polite] fieldset" do
      assert_select "legend", text: /\A\s*#{I18n.t("#{PICKER}.classroom")}/
      assert_equal [ "3e 1", "3e 2" ], css_select("label").map { it.text.strip }
      assert_select "label.flex.min-h-tap.items-center.gap-3.rounded-ln.border.border-line.px-4", 2
      assert_select "input[type=radio][name='student_registration[classroom_public_id]'][value='#{@deux.public_id}']" \
                    "[data-action='change->classroom--class-picker#sync']:not([disabled])"
    end
    assert_no_match(/3e 3/, response.body)
  end

  test "IL-05: a full classroom stays visible, disabled, with « Complète » in its label" do
    create_student(classroom: @un)

    classrooms

    assert_select "label.opacity-60", 1
    assert_select "label.opacity-60", text: /3e 1/ do
      assert_select "input[type=radio][disabled][value='#{@un.public_id}']"
      assert_select "span", text: I18n.t("#{PICKER}.full")
    end
    assert_select "input[type=radio][value='#{@deux.public_id}']:not([disabled])"
  end

  test "IL-04: never a headcount, a teacher, a student nor a token" do
    create_teacher(classrooms: [ @deux ], last_name: "Yao", first_name: "Konan")
    create_student(classroom: @deux, last_name: "Bamba", first_name: "Issa")

    classrooms

    [ "Yao", "Konan", "Bamba", "Issa", @deux.reload.link_token, @deux.join_code, "/ 80", "élève" ].each do |secret|
      assert_not_includes response.body, secret
    end
  end

  test "the fields follow the scope of the page" do
    classrooms(scope: "student_classroom_choice")

    assert_select "input[type=radio][name='student_classroom_choice[classroom_public_id]']", 2

    classrooms(scope: "other")

    assert_select "input[type=radio][name='student_registration[classroom_public_id]']", 2
  end

  test "IL-06: a level without an active classroom, a closed school or an unknown one: « not on Lnclass yet »" do
    closed = create_school(status: "inactive")
    create_classroom(school: closed, level: @level)

    [ [ @school.public_id, create_level.slug ], [ closed.public_id, @level.slug ], [ "sch-inconnu", "3eme" ] ].each do |ids|
      classrooms(*ids)

      assert_response :success
      assert_select "turbo-frame#picker_classrooms", text: /#{Regexp.escape(I18n.t("#{PICKER}.not_found_title"))}/
      assert_select "input[type=radio]", 0
    end
  end

  test "the 31st request of a minute from the same address receives 429, with the error state in the frame" do
    30.times do
      classrooms

      assert_response :success
    end

    classrooms

    assert_response :too_many_requests
    assert_select "turbo-frame#picker_classrooms [role=alert]", text: /#{Regexp.escape(I18n.t("#{PICKER}.rate_limited"))}/
    assert_select "turbo-frame#picker_classrooms a[href='#{school_picker_classrooms_path(@school.public_id, @level.slug)}']"
    assert_select "input[type=radio]", 0
  end
end
