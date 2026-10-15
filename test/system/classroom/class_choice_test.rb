require "application_system_test_case"

# UDR-0091 (CA-1 to CA-4, CA-7), in a real browser: « Choisis ta classe » in three numbered steps. The school of the last
# classroom is folded in one line with « Changer »; the levels are pills, the classrooms boxes, two per row on a phone and
# four from 700 px, a full one disabled; « Rejoindre cette classe » waits for a box. The pills answer the arrow keys.
# « Changer » opens the DRENA and school lists, without leaving the page, and empties steps 2 and 3.
class Classroom::ClassChoiceTest < ApplicationSystemTestCase
  PAGE = "classroom.student_classroom_choices.new".freeze
  PICKER = "classroom.student_registrations.class_picker".freeze
  BOX_TOPS = "[...document.querySelectorAll('#picker_classrooms label')].map((box) => Math.round(box.getBoundingClientRect().top))".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    school = create_school(drena:, name: "Lycée Classique d'Abidjan")
    sixieme = create_level(name: "6ème", position: 1)
    troisieme = create_level(name: "3ème", position: 4)
    create_classroom(school:, level: sixieme, name: "6e 1")
    @b, full = %w[A B C D].map { create_classroom(school:, level: troisieme, name: "3e #{it}") }.values_at(1, 2)
    full.update_column(:max_students, 1)
    create_student(classroom: full)
    @student = create_student(classroom: create_classroom(school:, level: troisieme, status: "archived"))
    sign_in_as @student
  end

  test "CA-1, CA-3, CA-4, CA-7 at 390 px: the school known, a pill, the boxes two by two, a full one disabled, the classroom joined" do
    with_mobile_viewport do
      visit new_student_classroom_choice_path

      within("#class-picker-school-summary") do
        assert_text "Lycée Classique d'Abidjan"
        assert_text "Abidjan 1"
        assert_selector "a[aria-label=\"#{I18n.t("#{PICKER}.change_label")}\"]", text: I18n.t("#{PICKER}.change")
      end
      assert_no_selector "select"
      assert_text I18n.t("#{PICKER}.level_first")
      assert_button I18n.t("#{PAGE}.submit"), disabled: true

      within("turbo-frame#picker_levels") { choose "3ème" }

      within("turbo-frame#picker_classrooms") do
        assert_selector "label", count: 4
        assert_selector :radio_button, "3e C", disabled: true
        assert_selector "label", text: /\A3e C\s+#{I18n.t("#{PICKER}.full")}\z/
        choose "3e B"
      end
      assert_no_text I18n.t("#{PICKER}.level_first")
      assert_equal 2, page.evaluate_script(BOX_TOPS).uniq.size, "deux cases par ligne au téléphone"
      click_on I18n.t("#{PAGE}.submit")
    end

    assert_toast I18n.t("classroom.student_classroom_choices.create.welcome")
    assert_current_path student_home_path
    assert_equal [ @b.id ], Orm::ClassroomStudent.where(student: @student, left_at: nil).pluck(:classroom_id)
  end

  test "CA-2, CA-7 at 820 px: four boxes on one row, the pills by the arrow keys; « Changer » opens the lists and empties the steps" do
    with_mobile_viewport([ 820, 1180 ]) do
      visit new_student_classroom_choice_path

      within("turbo-frame#picker_levels") { choose "6ème" }
      within("turbo-frame#picker_classrooms") { assert_selector "label", text: "6e 1", count: 1 }
      find_field("6ème").send_keys(:right)

      assert_checked_field "3ème"
      within("turbo-frame#picker_classrooms") { assert_selector "label", count: 4 }
      assert_equal 1, page.evaluate_script(BOX_TOPS).uniq.size, "quatre cases sur une ligne dès 700 px"

      assert_no_page_reload do
        find("a[aria-label=\"#{I18n.t("#{PICKER}.change_label")}\"]").click

        assert_no_selector "#class-picker-school-summary"
        assert_selector :select, "student_classroom_choice[drena_public_id]", selected: "Abidjan 1"
        assert_selector :select, "student_classroom_choice[school_public_id]", selected: I18n.t("#{PICKER}.school_prompt")
        assert_equal "student_classroom_choice[drena_public_id]", page.evaluate_script("document.activeElement.name")
        assert_no_selector "turbo-frame#picker_levels input, turbo-frame#picker_classrooms input"
        assert_text I18n.t("#{PICKER}.school_first")
        assert_button I18n.t("#{PAGE}.submit"), disabled: true

        select "Lycée Classique d'Abidjan", from: "student_classroom_choice[school_public_id]"
        within("turbo-frame#picker_levels") { assert_field "3ème", checked: false }
      end
      assert_current_path new_student_classroom_choice_path
    end
  end
end
