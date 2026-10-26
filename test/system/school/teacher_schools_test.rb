require "application_system_test_case"

# CA-H4 (UDR « écrans enseignant sans répétition » §3.4), in a real browser at 390 px: a teacher of three schools reads
# « 3 sur 3 », taps « Retirer » on one, confirms in the dialog, and lands on « 2 sur 3 » with the add card back. The
# refusals (last school, forged request) are controller tests.
class School::TeacherSchoolsTest < ApplicationSystemTestCase
  test "CA-H4: at 390 px, three schools: Retirer, confirm, then 2 sur 3 and the add card" do
    schools = [ "Lycée A", "Lycée B", "Lycée C" ].map { create_school(name: it) }
    teacher = create_teacher(school: schools.first)
    schools.drop(1).each { add_teacher_school(teacher, it) }
    sign_in_as teacher

    with_mobile_viewport do
      visit teacher_schools_path
      assert_selector "#schools_limit", text: "3 sur 3. Retirez-en un pour en ajouter un autre."
      assert_no_selector "#add_school"

      within("#teacher_school_#{schools.last.public_id}") { click_on "Retirer" }
      within("dialog#leave-school-#{schools.last.public_id}[open]") { click_on "Retirer", match: :first }

      assert_toast I18n.t("school.teacher_schools.destroy.left", school: "Lycée C")
      assert_selector "main p", text: "2 sur 3."
      assert_no_selector "#teacher_school_#{schools.last.public_id}"
      assert_selector "#add_school"
    end
  end
end
