require "application_system_test_case"

# ADR-0095, UDR-0101, UDR-0102 (§3.1, §3.2), in a real browser at 390 px: a student whose classroom is active opens
# « Changer de classe » from the « Classe » row of their profile, finds their classroom disabled with « Ta classe »,
# changes school with « Changer », picks a level and a classroom, reads the confirmation and confirms; they land on the home of the new classroom with the welcome toast.
class Classroom::ClassroomChangeTest < ApplicationSystemTestCase
  PICKER = "classroom.student_registrations.class_picker".freeze
  PAGE = "classroom.student_classroom_changes".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    cocody = create_school(drena:, name: "Lycée Moderne de Cocody")
    viateur = create_school(drena:, name: "Collège Saint-Viateur")
    level = create_level(name: "2nde")
    @a = create_classroom(school: cocody, level:, name: "2nde A")
    create_classroom(school: cocody, level:, name: "2nde B")
    @c = create_classroom(school: viateur, level:, name: "2nde C")
    @student = create_student(classroom: @a, first_name: "Awa", joined_at: 30.days.ago)
    sign_in_as @student
  end

  test "the student changes school by the cascade, confirms, and lands in the new classroom" do
    with_mobile_viewport do
      # UDR-0101 : depuis le profil, la ligne Classe ouvre la page, hors de la fenêtre.
      visit profile_path
      find("#profile_information a[aria-label='Changer classe, 2nde A']").click

      assert_current_path new_student_classroom_change_path
      within("turbo-frame#picker_levels") { choose "2nde" }
      within("turbo-frame#picker_classrooms") do
        assert_selector :radio_button, "2nde A #{I18n.t("#{PICKER}.current")}", disabled: true
      end
      assert_button I18n.t("#{PAGE}.new.submit"), disabled: true

      find("a[aria-label=\"#{I18n.t("#{PICKER}.change_label")}\"]").click
      select "Collège Saint-Viateur", from: "student_classroom_change[school_public_id]"
      within("turbo-frame#picker_levels") { choose "2nde" }
      within("turbo-frame#picker_classrooms") { choose "2nde C" }
      click_on I18n.t("#{PAGE}.new.submit")

      assert_selector "h1", text: I18n.t("#{PAGE}.confirm.title")
      within("dl") do
        assert_text "2nde A"
        assert_text "2nde C"
        assert_text I18n.t("#{PAGE}.confirm.other_school")
      end
      assert_equal [ @a.id ], Orm::ClassroomStudent.where(student: @student, left_at: nil).pluck(:classroom_id)
      click_on I18n.t("#{PAGE}.confirm.submit")
    end

    assert_toast I18n.t("#{PAGE}.create.welcome", classroom: "2nde C")
    assert_current_path student_home_path
    assert_equal [ @c.id ], Orm::ClassroomStudent.where(student: @student, left_at: nil).pluck(:classroom_id)
  end
end
