require "application_system_test_case"

# ID-18, ID-19 (ADR-0077, UDR-0070 §3.4, §3.5): a field team member removes Kofi from the « Direction » block of his
# school's page, reads him in « Directions retirées » and restores him, without a page reload. One short scenario: the
# system suite grows by at most 15 s per chantier (ADR-0069 §9); the team home card (ID-21), the cap (409), the content
# member and the forged requests live in the controller tests.
class Teams::SchoolStaffTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 2.days.ago)
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Bamba")
  end

  def ts(key, **) = I18n.t("shared.school_staff.#{key}", **)

  test "ID-18, ID-19: field removes Kofi, reads him in « Directions retirées », then restores him" do
    sign_in_as @field
    assert_selector "main#main", wait: SIGN_IN_WAIT
    visit school_path(@school.public_id)

    assert_no_page_reload do
      click_menu_action("#school_staff_#{@kofi.public_id}", ts("remove"))
      within("dialog[open]") { click_on ts("confirm.submit") }

      assert_toast ts("done", name: "Kofi Yao")
      assert_no_selector "#school_staff_#{@kofi.public_id}"
      assert_selector "#school_staff_places", text: ts("subtitle", used: 0, cap: 3)
      within("#school_archived_staff_#{@kofi.public_id}") do
        assert_text(/Kofi Yao\s+Retiré le .+ par Awa Bamba · Supprimé le .+/)
        click_on I18n.t("teams.schools.archived_staff.restore")
      end

      assert_toast I18n.t("teams.school_staff_restorations.create.done", name: "Kofi Yao")
      assert_no_selector "#school_archived_staff_#{@kofi.public_id}"
      assert_selector "#school_staff_#{@kofi.public_id}", text: "Kofi Yao"
      assert_selector "#school_staff_places", text: ts("subtitle", used: 1, cap: 3)
    end
    assert_nil Orm::SchoolStaff.find_by!(user_id: @kofi.id).archived_at
  end
end
