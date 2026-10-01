require "application_system_test_case"

# GD-14 (ADR-0071 §4.3, UDR-0056 §3.3): on « Enseignants », the direction opens the ⋮ menu of a teacher's row, chooses
# « Retirer de l'établissement » and confirms in the modal; the row goes without a page reload and the toast says how many
# assignments were archived. On a desktop, then on a 390 px phone without the page scrolling sideways.
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

  private

  def assert_withdrawal
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_admin_teachers_path
    assert_selector "#school_teachers tbody tr", count: 2
    assert_no_horizontal_scroll

    assert_no_page_reload do
      click_menu_action("#teacher_#{@teacher.public_id}", t("index.remove"))
      within("dialog[open]") do
        assert_selector "h2", text: t("index.remove_title", name: "Awa Koné")
        assert_text t("index.remove_body", first_name: "Awa")
        assert_no_horizontal_scroll
        click_on t("index.confirm")
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
