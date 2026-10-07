require "application_system_test_case"

# GD-19 then GD-23 (ADR-0071 §4.3, UDR-0056 §3.4, §3.5), on a 390 px phone: the direction opens « Enseignants retirés »
# and reinstates a teacher, whose row leaves without a reload; then another teacher detached from the same school reads
# the waiting screen, is refused by that school and joins another one, chosen by its DRENA (IE-18, ADR-0082 §4.3,
# UDR-0078 §3.9), without any school code; already configured, he lands on his home.
class SchoolAdmin::DepartedTeachersTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    drena = create_drena(name: "Abidjan 1")
    @a = create_school(drena:, name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    @b = create_school(drena:, name: "Lycée Classique d'Abidjan", school_code: "abc234")
    @admin = create_school_admin(school: @a, first_name: "Adjoua")
    @awa = departed(first_name: "Awa", last_name: "Koné")
  end

  def departed(**attributes)
    create_teacher(school: nil, **attributes).tap do |teacher|
      create_teacher_departure(teacher:, school: @a, detached_by: @admin)
    end
  end

  def t(key, **) = I18n.t(key, **)

  test "GD-19 : à 390 px, la direction réintègre un enseignant retiré, sans rechargement" do
    with_mobile_viewport do
      sign_in_as @admin
      assert_selector "main#main", wait: SIGN_IN_WAIT
      visit school_admin_departed_teachers_path

      assert_selector "h1", text: t("school_admin.departed_teachers.index.title")
      assert_selector "a#back-to-teachers[href='#{school_admin_teachers_path}']"
      assert_no_horizontal_scroll
      assert_no_page_reload do
        within("#departed_teacher_#{@awa.public_id}") do
          assert_selector "button[aria-label='Réintégrer Awa Koné']"
          click_on t("school_admin.departed_teachers.index.reinstate")
        end
        assert_toast t("school_admin.teacher_reinstatements.create.done", name: "Awa Koné")
        assert_no_selector "#departed_teacher_#{@awa.public_id}"
        assert_selector "#departed_teachers", text: t("school_admin.departed_teachers.index.empty.title")
      end
      assert_equal [ @a.id ], Orm::TeacherSchool.where(teacher: @awa).pluck(:school_id)
      assert_no_horizontal_scroll
    end
  end

  test "GD-23 : à 390 px, un enseignant retiré est refusé par A, puis rejoint B par DRENA → établissement et arrive sur son accueil" do
    yao = departed(first_name: "Yao", last_name: "Brou")
    with_mobile_viewport do
      sign_in_as yao

      assert_selector "h1", text: t("identity.pending_accounts.show.no_school.title"), wait: SIGN_IN_WAIT
      assert_no_field "school_join[school_code]"
      assert_no_horizontal_scroll
      select "Abidjan 1", from: "school_join[drena_public_id]"
      select "Lycée Moderne de Bouaké", from: "school_join[school_public_id]"
      click_on t("identity.pending_accounts.show.join")

      assert_selector "#school_join_school_public_id_error", text: "Cet établissement ne peut pas être rejoint."
      assert_no_horizontal_scroll

      select "Lycée Classique d'Abidjan", from: "school_join[school_public_id]"
      click_on t("identity.pending_accounts.show.join")

      assert_toast t("identity.pending_school_joins.create.welcome", school: "Lycée Classique d'Abidjan")
      assert_current_path teacher_home_path
      assert_equal [ [ @b.id, true ] ], Orm::TeacherSchool.where(teacher: yao).pluck(:school_id, :primary)
    end
  end

  private

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
