require "application_system_test_case"

# GD-14 (ADR-0071 §4.3, UDR-0056 §3.3): on « Enseignants », the direction opens the ⋮ menu of a teacher's row, chooses
# « Retirer de l'établissement » and confirms in the modal; the row goes without a page reload and the toast says how many
# assignments were archived. On a desktop, then on a 390 px phone without the page scrolling sideways.
# Lever 3b of ecrans-direction-lents (UDR-0056, amendment of 2026-10-04): the confirmation is no longer in the row, it is
# loaded on demand in the shared « modal » frame; the same title, text, buttons and DELETE.
class SchoolAdmin::TeachersTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    classrooms = [ create_classroom(school: @school, name: "6ème 1"), create_classroom(school: @school, name: "6ème 2") ]
    @teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", classrooms:)
    classrooms.each { create_assignment(classroom: it, by: @teacher) }
    @colleague = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.teachers.#{key}", **)

  test "GD-14: on a desktop, the direction withdraws a teacher after confirming" do
    sign_in_as @admin

    assert_withdrawal
  end

  test "GD-14: on a 390 px phone, the same withdrawal, without horizontal scroll" do
    with_mobile_viewport do
      sign_in_as @admin

      assert_withdrawal
    end
  end

  # Lever 3b: « Annuler » closes the confirmation and empties the frame; the same entry loads it again.
  test "GD-14: cancelling the confirmation keeps the teacher, and the ⋮ entry loads it again" do
    sign_in_as @admin
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_teachers_path

    assert_no_page_reload do
      2.times do
        click_menu_action("#teacher_#{@teacher.public_id}", t("index.remove"))
        within("turbo-frame#modal dialog[open]") { click_on t("removal.cancel") }
        assert_no_selector "dialog[open]"
        assert_selector "turbo-frame#modal:empty", visible: :all
      end
    end
    assert_selector "#teacher_#{@teacher.public_id}", text: "Awa Koné"
    assert Orm::TeacherSchool.exists?(teacher_id: @teacher.id)
  end

  # Challenge empirique (2026-10-01) : le tableau défile dans sa carte, mais le menu ⋮ reste visible sans le faire glisser.
  test "GD-14: on a 390 px phone, each row's ⋮ menu is on screen without scrolling the table" do
    with_mobile_viewport do
      sign_in_as @admin
      assert_selector "main#main", wait: SIGN_IN_WAIT
      visit school_admin_teachers_path

      button = find("#teacher_#{@teacher.public_id} [aria-haspopup]")
      right = page.evaluate_script("arguments[0].getBoundingClientRect().right", button)
      assert_operator right, :<=, page.evaluate_script("window.innerWidth")
    end
  end

  # Bugfix menu-enseignants-masque (UDR-0042, amendement du 2026-09-28): the ⋮ menu of a row in the middle opens over
  # the actions cell of the next row. Before the fix, that cell (sticky, later in the page) was drawn above the open menu:
  # it hid part of « Retirer de l'établissement » and took its click. The other tests only open the last row's menu.
  test "GD-14: the ⋮ menu of a row in the middle is above the next rows, and its « Retirer » opens that teacher's confirmation" do
    create_teacher(school: @school, first_name: "Fanta", last_name: "Touré")
    sign_in_as @admin
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_teachers_path
    assert_selector "#school_teachers tbody tr", count: 3
    assert_selector "#school_teachers tbody tr:nth-child(2)#teacher_#{@teacher.public_id}"

    within("#teacher_#{@teacher.public_id}") { find("button[aria-haspopup=menu]").click }
    item = find("#teacher-actions-#{@teacher.public_id} [role=menuitem]", text: t("index.remove"))
    assert on_top?(item), "« #{t('index.remove')} » est masqué par la ligne suivante"

    item.click
    within("dialog[open]") do
      assert_selector "h2", text: t("index.remove_title", name: "Awa Koné")
      click_on t("index.cancel")
    end
    assert_no_selector "dialog[open]"
    assert Orm::TeacherSchool.exists?(teacher_id: @teacher.id)
  end

  private

  # True when the point at the middle of the element is the element itself or one of its descendants: nothing is drawn
  # over it, and a click there reaches it.
  def on_top?(element)
    page.evaluate_script(<<~JS, element)
      (element => {
        const box = element.getBoundingClientRect()
        return element.contains(document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2))
      })(arguments[0])
    JS
  end

  def assert_withdrawal
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_teachers_path
    assert_selector "#school_teachers tbody tr", count: 2
    assert_no_horizontal_scroll

    assert_no_page_reload do
      click_menu_action("#teacher_#{@teacher.public_id}", t("index.remove"))
      within("turbo-frame#modal dialog[open]") do
        assert_selector "h2", text: t("removal.title", name: "Awa Koné")
        assert_text t("removal.body", first_name: "Awa")
        assert page.evaluate_script("document.activeElement.textContent.trim()") == t("removal.cancel"), "le focus est sur « Annuler »"
        assert_no_horizontal_scroll
        click_on t("removal.confirm")
      end

      assert_toast t("destroy.detached", name: "Awa Koné", count: 2)
      assert_no_selector "#teacher_#{@teacher.public_id}"
      assert_no_selector "dialog[open]"
    end
    assert_selector "#teacher_#{@colleague.public_id}", text: "Yao Brou"
    assert_no_horizontal_scroll
    assert_not Orm::TeacherSchool.exists?(teacher_id: @teacher.id)
    assert_equal 2, Orm::ClassroomAssignment.where(assigned_by: @teacher, status: "archived").count
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
