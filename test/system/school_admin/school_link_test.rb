require "application_system_test_case"

# IE-07 (ADR-0082 §4.1, UDR-0078 §3.7), replacing GD-04: the direction's invitation link is stable. On a 390 px phone,
# the block shows the /i/<token> link, « Copier le lien » and « Partager sur WhatsApp », without the school's code nor
# « Changer le lien », and fits the width. The arrival page behind the link is tested end to end with Lot D.
class SchoolAdmin::SchoolLinkTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.schools.link.#{key}", **)

  test "IE-07: on a 390 px phone, the direction reads a stable /i/ link, without code nor « Changer le lien »" do
    with_mobile_viewport do
      sign_in_as @admin
      assert_selector "main#main", wait: SIGN_IN_WAIT
      visit school_admin_school_path

      token = @school.reload.direction_invite_token
      within("#school_link_block") do
        assert_selector "a#school_link_value", text: %r{/i/#{token}\z}
        assert_button t(:copy)
        assert_link t(:share_whatsapp)
        assert_no_button "Changer le lien"
        assert_no_selector "#school_code_value"
        assert_no_text "K7M-4QZ"
      end
      assert_no_selector "dialog#change-school-link"
      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                      page.evaluate_script("document.documentElement.clientWidth")
    end
  end
end
