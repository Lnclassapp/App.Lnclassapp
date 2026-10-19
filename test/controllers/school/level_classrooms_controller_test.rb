require "test_helper"

# IL-04, IL-05, IL-06 (ADR-0085 §4.2, UDR-0081 §3.3): the classrooms of a level, public and limited to 30 requests a
# minute — the « picker_classrooms » frame of the student cascade. One radio per active classroom; a full one disabled,
# with « Complète » in its label; never a headcount, a ceiling, a teacher, a student nor a link token. UDR-0091: as boxes.
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

  # UDR-0091 §3.1 : de grandes cases de 64 px, 2 par ligne puis 4 dès 700 px ; la case choisie en brand, avec sa coche.
  test "IL-04: the frame lists the active classrooms of the level as big radio boxes, each a whole tap target" do
    classrooms(scope: "student_registration")

    assert_response :success
    assert_select "turbo-frame#picker_classrooms.block.transition-opacity[aria-live=polite]" do
      assert_select ".sr-only", text: I18n.t("#{PICKER}.classrooms_found", count: 2)
      assert_select "div.grid.grid-cols-2[class~='min-[700px]:grid-cols-4']" do
        assert_equal [ "3e 1", "3e 2" ], css_select("label").map { it.text.strip }
        assert_select "label.group.relative.min-h-16.rounded-ln.border.border-line.has-checked\\:border-brand.has-checked\\:bg-brand-soft", 2
        assert_select "label span.font-display", text: "3e 2"
        assert_select "label svg.hidden.group-has-checked\\:block[aria-hidden=true]", 2
      end
      assert_select "input[type=radio][name='student_registration[classroom_public_id]'][value='#{@deux.public_id}'][required]" \
                    "[data-action='change->classroom--class-picker#sync']:not([disabled])"
      assert_select "fieldset, legend, select", 0
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

    [ "Yao", "Konan", "Bamba", "Issa", @deux.reload.link_token, "/ 80", "élève" ].each do |secret|
      assert_not_includes response.body, secret
    end
  end

  test "UDR-0091 §3.6: a single classroom is announced in the singular" do
    single = create_school
    create_classroom(school: single, level: @level)

    classrooms(single.public_id)

    assert_select "turbo-frame#picker_classrooms .sr-only", text: "1 classe trouvée."
  end

  test "the fields follow the scope of the page" do
    classrooms(scope: "student_classroom_choice")

    assert_select "input[type=radio][name='student_classroom_choice[classroom_public_id]']", 2

    classrooms(scope: "other")

    assert_select "input[type=radio][name='student_registration[classroom_public_id]']", 2
  end

  # UDR-0102 §3.1, §4 : « Changer de classe » passe la classe actuelle de l'élève ; sa case est désactivée et dit « Ta classe ».
  test "UDR-0102: the current classroom is disabled with « Ta classe », in place of « Complète », and nothing more is said" do
    create_student(classroom: @un)

    classrooms(scope: "student_classroom_change", current: @deux.public_id)

    assert_select "input[type=radio][name='student_classroom_change[classroom_public_id]']", 2
    assert_select "label.opacity-60", 2
    assert_select "label.opacity-60", text: /3e 2/ do
      assert_select "input[type=radio][disabled][value='#{@deux.public_id}']"
      assert_select "span", text: I18n.t("#{PICKER}.current")
      assert_select "span", text: I18n.t("#{PICKER}.full"), count: 0
    end
    assert_select "label", text: /3e 1/ do
      assert_select "span", text: I18n.t("#{PICKER}.full")
    end
  end

  test "UDR-0102: without current, or with a forged one, no box says « Ta classe »" do
    [ {}, { current: "x'>&lt;b" }, { current: "cls-inconnu" } ].each do |params|
      classrooms(**params)

      assert_select "input[type=radio][disabled]", 0
      assert_no_match(/#{I18n.t("#{PICKER}.current")}/, response.body)
    end
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
