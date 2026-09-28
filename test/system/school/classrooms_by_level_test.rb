require "application_system_test_case"

# CN-02, CN-05, CN-06, CN-08, CN-10, ADR-0059, UDR-0046 : sur la fiche d'un établissement, « + » ajoute la « 6ème 5 »,
# « − » retire une classe vide après confirmation, et refuse une classe qui a un élève ; sans rechargement, au bureau
# comme à 390 px.
class School::ClassroomsByLevelTest < ApplicationSystemTestCase
  setup do
    referential = seed_referential
    @school = create_school(name: "Lycée Moderne de Cocody", cycle: "both")
    @sixths = (1..4).map { create_classroom(school: @school, level: referential[:levels]["6eme"], name: "6ème #{it}") }
    sign_in_as create_team_member
    visit school_path(@school.public_id)
  end

  def sixth_row = find("#level_classrooms_6eme")
  def sixth_count(count) = "[role=group][aria-label='6ème : #{count} classes']"

  # Un marqueur posé dans la page survit à la mise à jour : la preuve qu'elle n'a pas été rechargée.
  def mark_page = page.execute_script("window.levelMark = true")
  def assert_not_reloaded = assert(page.evaluate_script("window.levelMark === true"), "la page a été rechargée")

  def add_sixth
    within("#level_classrooms_6eme") { click_on "Ajouter une classe de 6ème" }
  end

  def remove_sixth(confirm: "Retirer la classe")
    within("#level_classrooms_6eme") { click_on "Retirer une classe de 6ème" }
    within("dialog[open]") { click_on confirm }
  end

  def add_then_remove
    mark_page
    add_sixth

    assert_toast "Classe « 6ème 5 » ajoutée."
    within("#level_classrooms_6eme") { assert_selector sixth_count(5) }
    assert_selector "#school_classrooms_title", text: "Classes (5)"
    assert_selector "#school_classrooms a", text: "6ème 5"
    assert Orm::Classroom.exists?(school: @school, name: "6ème 5")

    within("#level_classrooms_6eme") { click_on "Retirer une classe de 6ème" }
    within("dialog[open]") do
      assert_selector "h2", text: "Retirer la classe « 6ème 5 » ?"
      assert_text "supprimée définitivement"
      click_on "Retirer la classe"
    end

    assert_toast "Classe « 6ème 5 » retirée."
    within("#level_classrooms_6eme") { assert_selector sixth_count(4) }
    assert_no_selector "#school_classrooms a", text: "6ème 5"
    assert_not Orm::Classroom.exists?(school: @school, name: "6ème 5")
    assert_not_reloaded
  end

  def refuse_used
    create_student(classroom: @sixths.last)
    mark_page

    remove_sixth

    assert_toast "Cette classe a des élèves : archivez-la plutôt."
    assert_no_selector "dialog[open]"
    within("#level_classrooms_6eme") { assert_selector sixth_count(4) }
    assert Orm::Classroom.exists?(@sixths.last.id)
    assert_not_reloaded
  end

  test "« + » ajoute la 6ème 5, « − » la retire après confirmation, sans rechargement" do
    add_then_remove
  end

  test "« − » refuse une classe qui a un élève, et rien ne change" do
    refuse_used
  end

  test "« Annuler » ferme la confirmation sans rien retirer" do
    remove_sixth(confirm: "Annuler")

    assert_no_selector "dialog[open]"
    assert_equal 4, Orm::Classroom.where(school: @school).count
  end

  test "les mêmes parcours sur un écran de 390 px, avec des commandes de 48 px et sans défilement horizontal" do
    with_mobile_viewport do
      visit school_path(@school.public_id)

      sizes = sixth_row.all("button", minimum: 2).map { page.evaluate_script("[arguments[0].offsetWidth, arguments[0].offsetHeight]", it) }
      assert(sizes.all? { |width, height| width >= 48 && height >= 48 }, sizes.inspect)
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

      add_then_remove
      refuse_used
    end
  end
end
