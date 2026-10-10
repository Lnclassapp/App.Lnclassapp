require "application_system_test_case"

# ADR-0088, UDR-0083 : depuis la page de son niveau, la direction archive une classe peuplée après la confirmation chiffrée,
# la voit passer en fin de niveau avec son badge, la restaure ; archive le niveau ; les archives anciennes se montrent à la
# demande. Au bureau comme sur un téléphone de 390 px (⋮ de 48 px, sans défilement horizontal).
class SchoolAdmin::ClassroomArchivalTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT
  RESPONSE_WAIT = 10

  setup do
    @school = create_school(name: "Collège Moderne de Bouaké", cycle: "both")
    @level = create_level(name: "3ème", position: 4)
    @first = create_classroom(school: @school, level: @level, name: "3ème 1")
    @second = create_classroom(school: @school, level: @level, name: "3ème 2")
    Array.new(2) { create_student(classroom: @first) }
    Orm::TeacherClassroom.create!(teacher: create_teacher(school: @school), classroom: @first)
    @admin = create_school_admin(school: @school)
  end

  def assert_toast(text) = using_wait_time(RESPONSE_WAIT) { super }

  def open_level(archives: nil)
    sign_in_as @admin
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_level_path("3eme", archives:)
    assert_selector "#level_classrooms"
  end

  def card(classroom) = "#classroom_#{classroom.public_id}"

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  def archive_first
    assert_no_page_reload do
      click_menu_action(card(@first), "Archiver la classe")
      within("dialog[open]") do
        assert_selector "h2", text: "Archiver la classe 3ème 1 ?"
        assert_text "2 élèves et 1 enseignant ne la verront plus. Rien n'est supprimé"
        click_on "Archiver la classe"
      end

      assert_toast "Classe « 3ème 1 » archivée."
      assert_selector "#{card(@first)} span", text: "Archivée"
      assert_selector "p", text: "1 classe · 0 élève"
    end
  end

  test "la direction archive une classe peuplée, la voit en fin de niveau, puis la restaure" do
    open_level

    archive_first
    assert_equal "archived", Orm::Classroom.find(@first.id).status
    assert_equal 2, Orm::ClassroomStudent.where(classroom_id: @first.id, left_at: nil).count
    assert_equal [ "3ème 2", "3ème 1" ], all("#level_classrooms > li p.truncate").map(&:text)

    assert_no_page_reload do
      click_menu_action(card(@first), "Restaurer la classe")

      assert_toast "Classe « 3ème 1 » restaurée."
      assert_no_selector "#{card(@first)} span", text: "Archivée"
      assert_selector "p", text: "2 classes · 2 élèves"
    end
    assert_equal "active", Orm::Classroom.find(@first.id).status
  end

  test "à 390 px, le ⋮ mesure 48 px, la direction archive le niveau, et les archives anciennes se montrent à la demande" do
    old = create_classroom(school: @school, level: @level, name: "3ème 3", status: "archived", archived_at: 8.days.ago)
    with_mobile_viewport do
      open_level

      sizes = find("main").all("button[aria-haspopup=menu]").map { page.evaluate_script("[arguments[0].offsetWidth, arguments[0].offsetHeight]", it) }
      assert_equal 3, sizes.size
      assert(sizes.all? { |width, height| width >= 48 && height >= 48 }, sizes.inspect)
      assert_no_horizontal_scroll
      assert_no_selector card(old)

      find("button[aria-label='Actions du niveau 3ème']").click
      click_on "Archiver le niveau"
      within("dialog[open]") do
        assert_selector "h2", text: "Archiver les 2 classes de 3ème ?"
        assert_operator page.evaluate_script("arguments[0].getBoundingClientRect().right", find("h2")), :<=, 390
        click_on "Archiver le niveau"
      end

      assert_toast "2 classes de 3ème archivées."
      assert_selector "#{card(@first)} span", text: "Archivée"
      assert_no_selector "button[aria-label='Actions du niveau 3ème']"
      click_on "Afficher les archives (1)"
      assert_selector card(old)
      assert_no_horizontal_scroll
    end
    assert_equal %w[archived archived archived], Orm::Classroom.order(:name).pluck(:status)
  end
end
