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

  # Sous charge (4 navigateurs en parallèle), une réponse Turbo Stream dépasse parfois l'attente par défaut de Capybara.
  RESPONSE_WAIT = 10

  def sixth_row = find("#level_classrooms_6eme")
  def assert_toast(text) = using_wait_time(RESPONSE_WAIT) { super }
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

    assert_toast "Cette classe a des élèves : elle ne peut plus être retirée."
    assert_no_selector "dialog[open]"
    within("#level_classrooms_6eme") { assert_selector sixth_count(4) }
    assert Orm::Classroom.exists?(@sixths.last.id)
    assert_not_reloaded
  end

  # Un toast d'erreur reste jusqu'à sa fermeture et peut couvrir l'en-tête (au téléphone surtout) : on le ferme par son
  # vrai bouton, comme le ferait l'équipe, et on attend qu'il ait quitté la page.
  def dismiss_toasts
    all("#toasts button[data-action='toast#dismiss']").each do |button|
      button.click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      nil # un toast de succès s'est fermé seul entre la recherche et le clic : il a déjà quitté la page
    end
    assert_no_selector "#toasts [data-controller=toast]"
  end

  # Après un refus, la confirmation est vraiment refermée : la page reste utilisable sans rechargement.
  def assert_page_usable
    assert_no_selector "dialog[open]"
    assert page.evaluate_script("document.querySelectorAll('dialog:modal').length === 0"), "une <dialog> reste modale"
    dismiss_toasts
    # À 390 px, le bouton ⋮ ramené juste au bord de l'écran passe sous la barre supérieure collante : on remonte en haut.
    page.execute_script("window.scrollTo(0, 0)")
    within("#school_header") { find("button[aria-haspopup=menu]").click }
    assert_selector "#school_header [role=menu]", visible: true
    find("#school_header button[aria-haspopup=menu]").click
    within("#level_classrooms_5eme") { click_on "Ajouter une classe de 5ème" }
    assert_toast "Classe « 5ème 1 » ajoutée."
    assert_not_reloaded
  end

  # Un autre onglet a retiré la classe entre l'ouverture de la confirmation et son envoi : 404.
  def refuse_gone
    mark_page
    within("#level_classrooms_6eme") { click_on "Retirer une classe de 6ème" }
    Orm::Classroom.where(id: @sixths.last.id).delete_all
    within("dialog[open]") { click_on "Retirer la classe" }

    assert_toast "Cette classe n'existe plus"
    assert_page_usable
  end

  test "« + » ajoute la 6ème 5, « − » la retire après confirmation, sans rechargement" do
    add_then_remove
  end

  test "« − » refuse une classe qui a un élève, et rien ne change ; la page reste utilisable" do
    refuse_used
    assert_page_usable
  end

  test "« − » sur une classe retirée par un autre onglet : 404, et la page reste utilisable" do
    refuse_gone
  end

  test "après « Désactiver » depuis l'en-tête, le bloc n'offre plus « + » et dit pourquoi, sans rechargement" do
    mark_page
    click_menu_action("#school_header", "Désactiver")
    within("dialog[open]") { click_on "Désactiver l'établissement" }

    assert_toast "désactivé"
    assert_selector "#school_level_classrooms_inactive", text: "Seul un établissement actif reçoit de nouvelles classes."
    assert_no_button "Ajouter une classe de 6ème"
    assert_button "Retirer une classe de 6ème"
    assert_not_reloaded
  end

  test "un passage en brouillon par « Modifier » retire aussi « + » du bloc" do
    mark_page
    click_menu_action("#school_header", "Modifier")
    within("dialog[open]") do
      select "Brouillon", from: "Statut"
      click_on "Enregistrer"
    end

    assert_selector "#school_level_classrooms_inactive"
    assert_no_button "Ajouter une classe de 6ème"
    assert_not_reloaded
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
      assert_page_usable
    end
  end

  test "à 390 px, un 404 laisse aussi la page utilisable" do
    with_mobile_viewport do
      visit school_path(@school.public_id)
      refuse_gone
    end
  end
end
