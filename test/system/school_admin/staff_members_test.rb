require "application_system_test_case"

# ID-10 to ID-13 (ADR-0077, UDR-0070 §3.3, §3.4), on a 390 px phone: Aya, direction for 2 days, has no ⋮ menu and reads the
# newcomer note. Kofi, direction for 10 days, reads her arrival on « Travail des élèves », then removes her from
# Établissement → « Direction » → ⋮ → confirmation, without a page reload; Aya's open session is closed.
# One scenario, one browser: the system suite grows by at most 15 s per chantier (ADR-0069 §9); the branches, and Aya's
# next request sent to « Se connecter », live in the controller tests. Aya's cookies are dropped, her server session stays.
class SchoolAdmin::StaffMembersTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 10.days.ago)
    @aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 2.days.ago)
  end

  def ts(key, **) = I18n.t("shared.school_staff.#{key}", **)

  test "ID-10 to ID-13: Aya has no ⋮ menu; Kofi reads her arrival, removes her, and she is signed out" do
    with_mobile_viewport do
      assert_newcomer_view
      assert_equal 1, Orm::Session.where(user_id: @aya.id).count
      page.driver.browser.manage.delete_all_cookies
      assert_removal
    end
  end

  private

  def assert_newcomer_view
    sign_in_as @aya
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_no_selector "#staff_arrivals"
    visit school_admin_school_path
    within("#school_staff") do
      assert_selector "li", count: 2
      assert_no_selector "button[aria-haspopup=menu]"
      assert_text ts("newcomer")
    end
  end

  def assert_removal
    sign_in_as @kofi
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path school_admin_classrooms_path
    within("#staff_arrivals[role=status]") { assert_text(/Aya Koné a rejoint la direction le .+ \(avec le code de l'établissement\)\./) }

    visit school_admin_school_path
    assert_selector "#school_staff_places", text: ts("subtitle", used: 2, cap: 3)
    within("#school_staff_#{@kofi.public_id}") { assert_no_selector "button[aria-haspopup=menu]" }
    assert_no_horizontal_scroll

    assert_no_page_reload do
      click_menu_action("#school_staff_#{@aya.public_id}", ts("remove"))
      within("dialog[open]") do
        assert_selector "h2", text: ts("confirm.title", name: "Aya Koné")
        assert_text ts("confirm.body")
        assert_no_horizontal_scroll
        click_on ts("confirm.submit")
      end

      assert_toast ts("done.female", name: "Aya Koné")
      assert_no_selector "#school_staff_#{@aya.public_id}"
      assert_no_selector "dialog[open]"
      assert_selector "#school_staff_places", text: ts("subtitle", used: 1, cap: 3)
    end
    assert_selector "#school_staff_#{@kofi.public_id}", text: "Kofi Yao"
    assert_equal @kofi.id, Orm::SchoolStaff.find_by!(user_id: @aya.id).archived_by_id
    assert_equal 0, Orm::Session.where(user_id: @aya.id).count
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end
end
