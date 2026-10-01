require "application_system_test_case"

# GD-04 (ADR-0071 §4.2, UDR-0056 §3.2): on a 390 px phone, the direction opens « Changer le lien », cancels once, then
# confirms; the new link replaces the old one without a reload, and the old /e/ link answers « Code d'établissement
# invalide » while the new one opens the sign-up with the school filled in.
class SchoolAdmin::SchoolLinkTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.schools.link.change.#{key}", **)

  test "GD-04: on a 390 px phone, the direction changes the link after confirming; the old link is refused" do
    with_mobile_viewport do
      sign_in_as @admin
      assert_selector "main#main", wait: SIGN_IN_WAIT
      visit school_admin_school_path

      within("#school_link_block") { click_on t(:trigger) }
      within("dialog#change-school-link[open]") do
        assert_text t(:title)
        assert_text t(:warning)
        click_on t(:cancel)
      end
      assert_no_selector "dialog#change-school-link[open]"
      assert_equal "k7m4qz", @school.reload.school_code

      assert_no_page_reload do
        within("#school_link_block") { click_on t(:trigger) }
        within("dialog#change-school-link[open]") { click_on t(:confirm) }
        assert_no_selector "#school_code_value", exact_text: "K7M-4QZ"
      end
      new_code = @school.reload.school_code
      display = Entities::School::SchoolCode.display(new_code)
      assert_toast I18n.t("school_admin.school_links.update.done", code: display)
      assert_selector "#school_code_value", exact_text: display
      assert_selector "a#school_link_value", text: %r{/e/#{new_code}\z}
      assert_no_selector "dialog#change-school-link[open]"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                      page.evaluate_script("document.documentElement.clientWidth")

      sign_out
      visit school_code_signup_path("k7m4qz")
      assert_text I18n.t("identity.teacher_registrations.new.invalid_code.title")

      visit school_code_signup_path(new_code)
      assert_text "Lycée Moderne de Bouaké"
      assert_no_text I18n.t("identity.teacher_registrations.new.invalid_code.title")
    end
  end
end
