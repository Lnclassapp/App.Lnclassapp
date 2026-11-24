require "application_system_test_case"

# CA-3, CA-5, CA-6 (accueil-eleve-grille-plus, UDR accueil-eleve-grille-plus §3), at 390 px: the « Plus » sheet of the student home opens from the
# last tile of the grid, says « Bientôt disponible » for an entry without a screen, and hands the focus back on Escape. Its markup is proved in
# test/controllers/classroom/student_homes_controller_test.rb.
class Classroom::StudentHomeMoreTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique", sigle: "LCA"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    create_course(material: create_material(name: "SVT", category: "science"), level: @classroom.level)
    subscribe_student(@student)
    sign_in_as @student
  end

  def more(key, **) = I18n.t("shared.navigation.more.#{key}", **)

  test "CA-3: « Plus » opens a sheet at the bottom of the screen, four columns, at least a quarter of its height" do
    with_mobile_viewport do
      visit student_home_path
      find("#student_more_button").click

      assert_selector "dialog#student_more_sheet[open]"
      assert_selector "#student_more_sheet-title", text: more("title")
      NavigationHelper::STUDENT_MORE.each { assert_text more("entries.#{it.key}") }
      dialog = find("dialog#student_more_sheet").rect
      viewport_height = page.evaluate_script("window.innerHeight")
      assert_operator dialog.height, :>=, viewport_height * 0.25 - 1
      assert_in_delta viewport_height, dialog.y + dialog.height, 2, "la feuille touche le bas de l'écran"
      assert_equal 4, page.evaluate_script("getComputedStyle(document.querySelector('#student_more_sheet ul')).gridTemplateColumns.split(' ').length")
    end
  end

  test "CA-5: an entry without a screen says « Bientôt disponible » in the status, and the address does not change" do
    with_mobile_viewport do
      visit student_home_path
      path = page.current_path
      find("#student_more_button").click
      click_button more("entries.study_room")

      assert_selector "#student_more_status[role=status]", text: more("soon")
      assert_equal path, page.current_path
      assert_selector "dialog#student_more_sheet[open]"
    end
  end

  test "CA-4: « S'abonner » leads to the subscription page" do
    with_mobile_viewport do
      visit student_home_path
      find("#student_more_button").click
      click_link more("entries.subscribe")

      assert_current_path billing_subscription_path
    end
  end

  test "CA-6: Escape closes the sheet and the focus goes back to « Plus »" do
    with_mobile_viewport do
      visit student_home_path
      find("#student_more_button").click
      assert_selector "dialog#student_more_sheet[open]"
      find("dialog#student_more_sheet").send_keys(:escape)

      assert_no_selector "dialog#student_more_sheet[open]"
      assert_equal "student_more_button", page.evaluate_script("document.activeElement.id")
    end
  end
end
