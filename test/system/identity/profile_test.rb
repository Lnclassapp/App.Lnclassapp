require "application_system_test_case"

# PR-01, PR-03, ADR-0055, UDR-0041: from the account menu, a student opens « Mon profil », reads their information,
# corrects their first name in the modal without a page reload, meets the 422 of an empty name, and their teacher
# then sees the new name in the class list. A teacher and a team member read the information of their role.
class Identity::ProfileTest < ApplicationSystemTestCase
  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, name: "Tle D 1")
    @teacher = create_teacher(school:, material: create_material(name: "SVT"), classrooms: [ @classroom ], first_name: "Yao")
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Koné", contact: "0701020304",
                              created_at: Time.zone.local(2026, 9, 1, 10))
  end

  def open_profile
    find("button[aria-controls='account-menu']").click
    find("#account-menu a[role=menuitem]", text: I18n.t("shared.navigation.profile")).click
    assert_current_path profile_path
  end

  test "the student reads their profile, then corrects their first name without a page reload; the teacher sees it" do
    sign_in_as @student
    open_profile

    within "#profile_information" do
      assert_text "Aya Koné"
      assert_text "07 01 02 03 04"
      assert_text "Tle D 1"
      assert_text "1 septembre 2026"
    end
    assert_selector "#profile_security a", text: "Changer mon PIN"

    assert_no_page_reload do
      within("#profile_information") { click_on "Modifier" }
      within "turbo-frame#modal dialog[open]" do
        assert_selector "h2", text: "Modifier mon nom"
        fill_in "profile_name[last_name]", with: " "
        click_on "Enregistrer"

        assert_selector "#profile_name_last_name_error", text: "Saisissez votre nom."
        assert_field "profile_name[first_name]", with: "Aya"
        fill_in "profile_name[last_name]", with: "Koné"
        fill_in "profile_name[first_name]", with: "Aya Marie"
        click_on "Enregistrer"
      end

      assert_toast "Votre nom est enregistré."
      assert_no_selector "turbo-frame#modal dialog[open]"
      within("#profile_information") { assert_text "Aya Marie Koné" }
    end
    assert Orm::AuditEvent.exists?(action: "profile.name_changed", actor_id: @student.id)

    sign_out
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)
    within("#student_#{@student.public_id}") { assert_text "Aya Marie Koné" }
  end

  test "a teacher reads their school and subject, a team member their role and active second factor" do
    sign_in_as @teacher
    open_profile
    within "#profile_information" do
      assert_text "Lycée Classique d'Abidjan"
      assert_text "SVT"
    end
    sign_out

    sign_in_as create_team_member(team_role: "content")
    open_profile
    within "#profile_information" do
      assert_text "Contenu"
      assert_text "Second facteur : actif"
    end
  end
end
