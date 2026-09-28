require "application_system_test_case"

# CP-01 to CP-06 (ADR-0063, UDR-0050): a teacher invites a colleague from the home — WhatsApp, copy — each share counted by
# the server; the colleague signs up by the link and the counter of the referrer moves. The same on a 390 px phone.
class Identity::InviteColleagueTest < ApplicationSystemTestCase
  INVITE = "identity.referrals.invite".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    create_material(name: "SVT", shortname: "SVT")
    @teacher = create_teacher(school: @school, first_name: "Aya")
    @token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
  end

  def shares = Orm::ReferralShare.where(user: @teacher).order(:id).pluck(:channel)

  test "CP-04, CP-05: the home offers the link; WhatsApp and copy are counted by the server" do
    sign_in_as @teacher
    visit teacher_home_path

    within "#invite_colleagues" do
      assert_text I18n.t("#{INVITE}.count", count: 0)
      assert_selector "a#referral_link", text: %r{/e/k7m4qz\?ref=#{@token}\z}
      whatsapp = find_link(I18n.t("#{INVITE}.whatsapp"))
      assert whatsapp[:href].start_with?("https://wa.me/?text=Bonjour")
      assert_includes CGI.unescape(whatsapp[:href]), "Lycée Classique d'Abidjan"
      assert find_link(I18n.t("#{INVITE}.sms"))[:href].start_with?("sms:?body=")
    end
    growth_shot("1280-accueil-enseignant-inviter", scroll_to: "#invite_colleagues")

    new_window = window_opened_by { click_on I18n.t("#{INVITE}.whatsapp") }
    new_window.close
    click_on I18n.t("#{INVITE}.copy")

    assert_toast I18n.t("#{INVITE}.copied")
    assert_equal @token, page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")[/ref=(\h+)/, 1]
    Timeout.timeout(10) { sleep 0.1 until shares.size == 2 }
    assert_equal %w[whatsapp copy], shares
  end

  test "CP-02, CP-06: a colleague signs up by the link; the referrer's counter then says 1" do
    visit school_code_signup_path("k7m4qz", ref: @token)

    assert_selector "#school-preview", text: "Lycée Classique d'Abidjan"
    fill_in "teacher_registration[last_name]", with: "Kouassi"
    fill_in "teacher_registration[first_name]", with: "Koffi"
    choose I18n.t("genders.male")
    fill_in "teacher_registration[contact]", with: "05 01 02 03 04"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_classrooms_path
    referee = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ @teacher.id ], Orm::Referral.where(referee:).pluck(:referrer_id)
    sign_out

    sign_in_as @teacher
    visit teacher_home_path
    assert_selector "#referral_count", text: "1"
    assert_selector "#referral_count", text: I18n.t("#{INVITE}.count_label", count: 1)
  end

  test "CP-05: on a 390 px phone, the four ways to share fit the width and the copy is counted" do
    with_mobile_viewport do
      sign_in_as @teacher
      visit teacher_invite_path

      assert_selector "#referral_share_actions a", text: I18n.t("#{INVITE}.whatsapp")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      growth_shot("390-inviter-un-collegue", desktop: false)
      click_on I18n.t("#{INVITE}.copy")

      assert_toast I18n.t("#{INVITE}.copied")
      Timeout.timeout(10) { sleep 0.1 until shares == %w[copy] }
    end
  end

  test "CP-05: the native share button appears only where the browser offers it" do
    sign_in_as @teacher
    visit teacher_invite_path

    native = page.evaluate_script("typeof navigator.share === 'function'")
    assert_equal native, has_button?(I18n.t("#{INVITE}.native"), wait: 1)
  end
end
