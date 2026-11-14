require "application_system_test_case"

# CA-06, CA-07 (chantier suppression-lecon), UDR-0172 : depuis la page d'une leçon, le menu ⋮ ouvre
# la confirmation ; confirmer renvoie au catalogue. Une leçon dont un élève s'est servi refuse dès l'ouverture et propose de la modifier.
class Teams::CourseDeletionTest < ApplicationSystemTestCase
  setup do
    sign_in_as create_team_member
    @course = create_course(name: "Les suites numériques", status: "published")
    @exercise = create_exercise(essential: create_essential(course: @course))
  end

  test "a lesson nobody used is deleted from its page, after a confirmation that names it, and the catalogue says so" do
    visit course_path(@course.slug)
    click_menu_action("#course_header", "Supprimer")

    within "turbo-frame#modal dialog[open]" do
      assert_text "Supprimer la fiche de cours « Les suites numériques » ?"
      assert_text "supprimés définitivement"
      click_on "Annuler"
    end
    assert_no_selector "turbo-frame#modal dialog[open]"
    assert Orm::Course.exists?(@course.id)

    click_menu_action("#course_header", "Supprimer")
    within("turbo-frame#modal dialog[open]") { click_on "Supprimer définitivement" }

    assert_current_path courses_path
    assert_toast "Fiche de cours « Les suites numériques » supprimée."
    assert_not Orm::Course.exists?(@course.id)
  end

  test "a lesson a student used refuses at once and opens its edit form instead" do
    create_essential_read(essential: @exercise.essential)
    visit course_path(@course.slug)
    click_menu_action("#course_header", "Supprimer")

    within "turbo-frame#modal dialog[open]" do
      assert_text "Cette fiche de cours ne peut pas être supprimée"
      assert_no_button "Supprimer définitivement"
      click_on "Modifier la fiche de cours"
    end

    within("turbo-frame#modal dialog[open]") { assert_field "course[name]", with: "Les suites numériques" }
    assert Orm::Course.exists?(@course.id)
  end

  test "a student who starts in between: the confirmation sent is refused and the modal turns into the refusal" do
    visit course_path(@course.slug)
    click_menu_action("#course_header", "Supprimer")
    within("turbo-frame#modal dialog[open]") { assert_text "Supprimer la fiche de cours" }
    create_exercise_session(exercise: @exercise)

    within("turbo-frame#modal dialog[open]") { click_on "Supprimer définitivement" }

    assert_toast "La fiche de cours « Les suites numériques » a servi à des élèves"
    within("turbo-frame#modal dialog[open]") { assert_link "Modifier la fiche de cours" }
    assert_current_path course_path(@course.slug)
    assert Orm::Course.exists?(@course.id)
  end
end
