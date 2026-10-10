require "application_system_test_case"

# ADR-0088, UDR-0083 : sur la fiche d'un établissement, l'équipe archive une classe peuplée depuis son menu ⋮ après une
# confirmation chiffrée, la restaure, archive un niveau ; une archivée de plus de 7 jours ne paraît que sous « Afficher les archives ».
class Teams::ClassroomArchivalTest < ApplicationSystemTestCase
  setup do
    levels = seed_referential[:levels]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    @classroom = create_classroom(school: @school, level: levels["6eme"], name: "6ème 1")
    @second = create_classroom(school: @school, level: levels["6eme"], name: "6ème 2")
    @old = create_classroom(school: @school, level: levels["5eme"], name: "5ème 1")
    @old.update_columns(status: "archived", archived_at: 9.days.ago)
    3.times { create_student(classroom: @classroom) }
    create_teacher(school: @school, classrooms: [ @classroom ])
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def card(classroom) = "li#classroom_#{classroom.public_id}"

  # Opens a ⋮ menu and returns its item. The page can still be hydrating or morphing (Turbo refresh) when the first click lands.
  def open_menu_item(label, item, text)
    3.times do
      find("button[aria-label='#{label}']").click
      return find(item, text:, wait: 2)
    rescue Capybara::ElementNotFound, Selenium::WebDriver::Error::StaleElementReferenceError
      next
    end
    flunk "menu « #{label} » did not open"
  end

  test "archiver une classe peuplée après la confirmation chiffrée, puis la restaurer" do
    visit school_path(@school.public_id)

    open_menu_item("Actions de la classe 6ème 1", "#classroom-menu-#{@classroom.public_id} button[role=menuitem]", "Archiver la classe").click

    within "dialog#archive-classroom-#{@classroom.public_id}[open]" do
      assert_text "3 élèves et 1 enseignant ne la verront plus"
      click_on "Archiver la classe"
    end

    assert_toast "Classe « 6ème 1 » archivée."
    assert_selector "#{card(@classroom)}", text: "Archivée"
    assert_equal "archived", @classroom.reload.status

    # La fiche est re-demandée après l'archivage (morphing) : on attend qu'elle soit posée avant d'ouvrir le menu suivant.
    visit school_path(@school.public_id)
    open_menu_item("Actions de la classe 6ème 1", "#classroom-menu-#{@classroom.public_id} a[role=menuitem]", "Restaurer la classe").click

    assert_toast "Classe « 6ème 1 » restaurée."
    assert_no_selector "#{card(@classroom)}", text: "Archivée"
    assert_equal "active", @classroom.reload.status
  end

  test "archiver un niveau, et n'afficher les archives anciennes que sur demande" do
    visit school_path(@school.public_id)

    assert_no_selector card(@old)
    click_on "Afficher les archives (1)"
    assert_selector card(@old), text: "Archivée"
    click_on "Masquer les archives"
    assert_no_selector card(@old)
    assert_link "Afficher les archives (1)"

    open_menu_item("Actions du niveau 6ème", "#level-menu-6eme button[role=menuitem]", "Archiver le niveau").click
    within "dialog#archive-level-6eme[open]" do
      assert_text "Archiver les 2 classes de 6ème ?"
      assert_text "3 élèves et 1 enseignant"
      click_on "Archiver le niveau"
    end

    assert_toast "2 classes archivées."
    assert_selector card(@classroom), text: "Archivée"
    assert_selector card(@second), text: "Archivée"
    assert_no_selector "#level-menu-6eme"
  end
end
