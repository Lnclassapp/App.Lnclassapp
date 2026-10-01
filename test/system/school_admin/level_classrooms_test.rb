require "application_system_test_case"

# GD-08, GD-09, GD-10 (ADR-0071 §4.2, UDR-0056 §3.2) : sur « Établissement », la direction ajoute la « 6ème 5 » par le
# « + » et la retire par le « − » après confirmation, sans rechargement ; une classe qui a un élève est refusée avec le
# motif de l'équipe. Au bureau comme sur un téléphone de 390 px, sans défilement horizontal.
class SchoolAdmin::LevelClassroomsTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT
  # Sous charge (plusieurs navigateurs en parallèle), une réponse Turbo Stream dépasse parfois l'attente par défaut.
  RESPONSE_WAIT = 10

  setup do
    referential = seed_referential
    @school = create_school(name: "Lycée Moderne de Bouaké", cycle: "both")
    @sixths = (1..4).map { create_classroom(school: @school, level: referential[:levels]["6eme"], name: "6ème #{it}") }
    @admin = create_school_admin(school: @school)
  end

  def assert_toast(text) = using_wait_time(RESPONSE_WAIT) { super }
  def sixth_count(count) = "[role=group][aria-label='6ème : #{count} classes']"

  def open_school
    sign_in_as @admin
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_school_path
    assert_selector "#school_level_classrooms #level_classrooms_6eme"
  end

  def add_then_remove
    assert_no_page_reload do
      within("#level_classrooms_6eme") { click_on "Ajouter une classe de 6ème" }

      assert_toast "Classe « 6ème 5 » ajoutée."
      within("#level_classrooms_6eme") { assert_selector sixth_count(5) }
      assert Orm::Classroom.exists?(school: @school, name: "6ème 5")

      within("#level_classrooms_6eme") { click_on "Retirer une classe de 6ème" }
      within("dialog[open]") do
        assert_selector "h2", text: "Retirer la classe « 6ème 5 » ?"
        click_on "Retirer la classe"
      end

      assert_toast "Classe « 6ème 5 » retirée."
      within("#level_classrooms_6eme") { assert_selector sixth_count(4) }
      assert_not Orm::Classroom.exists?(school: @school, name: "6ème 5")
    end
  end

  def refuse_used
    create_student(classroom: @sixths.last)

    assert_no_page_reload do
      within("#level_classrooms_6eme") { click_on "Retirer une classe de 6ème" }
      within("dialog[open]") { click_on "Retirer la classe" }

      assert_toast "Cette classe a des élèves : archivez-la plutôt."
      assert_no_selector "dialog[open]"
      within("#level_classrooms_6eme") { assert_selector sixth_count(4) }
    end
    assert Orm::Classroom.exists?(@sixths.last.id)
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  test "GD-08, GD-09, GD-10 : au bureau, « + » ajoute la 6ème 5, « − » la retire, une classe qui a servi est refusée" do
    open_school

    add_then_remove
    refuse_used
  end

  test "GD-08, GD-09 : à 390 px, les mêmes gestes, avec des commandes de 48 px et sans défilement horizontal" do
    with_mobile_viewport do
      open_school

      sizes = find("#level_classrooms_6eme").all("button", minimum: 2)
                                           .map { page.evaluate_script("[arguments[0].offsetWidth, arguments[0].offsetHeight]", it) }
      assert(sizes.all? { |width, height| width >= 48 && height >= 48 }, sizes.inspect)
      assert_no_horizontal_scroll

      add_then_remove
      assert_no_horizontal_scroll
    end
  end
end
