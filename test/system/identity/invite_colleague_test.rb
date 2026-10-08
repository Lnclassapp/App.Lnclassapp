require "application_system_test_case"

# CP-01 to CP-06 (ADR-0063, UDR-0050): a teacher invites a colleague from the home — WhatsApp, copy — each share counted by
# the server; the colleague signs up by the link and the counter of the referrer moves. The same on a 390 px phone.
# Since UDR-0054, the copy goes through the clipboard controller; identity--share counts it on clipboard:copied.
# Since UDR-0069 §3.6-§3.7 (RE-20), the home's block is shown below lg only; a wide screen has the sidebar card instead.
# IE-06 (ADR-0083 §4.1, UDR-0079 §3.6-§3.7): the link is /i/<referral token>, without the school code; the colleague
# arrives with the school and its DRENA already chosen, and signs up with a full name by the « colleague » way.
class Identity::InviteColleagueTest < ApplicationSystemTestCase
  INVITE = "identity.referrals.invite".freeze

  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Moderne de Cocody", school_code: "k7m4qz")
    create_material(name: "SVT", shortname: "SVT")
    @teacher = create_teacher(school: @school, first_name: "Awa")
    @token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
  end

  def shares = Orm::ReferralShare.where(user: @teacher).order(:id).pluck(:channel)

  test "CP-04, CP-05: the home offers the link on a phone; WhatsApp and copy are counted by the server" do
    with_mobile_viewport do
      sign_in_as @teacher
      visit teacher_home_path

      within "#invite_colleagues" do
        assert_text I18n.t("#{INVITE}.count", count: 0)
        assert_selector "a#referral_link", text: %r{/i/#{@token}\z}
        whatsapp = find_link(I18n.t("#{INVITE}.whatsapp"))
        assert whatsapp[:href].start_with?("https://wa.me/?text=Bonjour")
        assert_includes CGI.unescape(whatsapp[:href]), "Lycée Moderne de Cocody"
        assert_includes CGI.unescape(whatsapp[:href]), "/i/#{@token}"
        assert_no_match(/k7m4qz/i, CGI.unescape(whatsapp[:href]))
        assert find_link(I18n.t("#{INVITE}.sms"))[:href].start_with?("sms:?body=")
      end
      growth_shot("390-accueil-enseignant-inviter", scroll_to: "#invite_colleagues", desktop: false)

      within "#invite_colleagues" do
        new_window = window_opened_by { click_on I18n.t("#{INVITE}.whatsapp") }
        new_window.close
        click_on I18n.t("#{INVITE}.copy")
      end

      assert_toast I18n.t("shared.clipboard.copied_link")
      assert_equal @token, page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")[%r{/i/(\h+)\z}, 1]
      Timeout.timeout(10) { sleep 0.1 until shares.size == 2 }
      assert_equal %w[whatsapp copy], shares
    end
  end

  test "IE-06, CP-02, CP-06: Awa's link, without the code, signs a colleague up by the « colleague » way; her counter says 1" do
    sign_in_as @teacher
    visit teacher_home_path
    link = find("a#sidebar_referral_link")[:href]
    assert_match %r{/i/#{@token}\z}, link
    assert_no_match(/k7m4qz/i, link)
    sign_out

    visit link
    within "#school-preview" do
      assert_text "Lycée Moderne de Cocody"
      assert_text "Abidjan 1"
    end
    assert_no_field "teacher_registration[drena_public_id]"
    assert_no_field "teacher_registration[school_code]"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Koffi"
    choose I18n.t("genders.male")
    fill_in "teacher_registration[contact]", with: "0501020304"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_classrooms_path
    referee = Orm::User.find_by!(contact: "0501020304")
    assert_equal [ "KOUASSI", "Koffi" ], [ referee.last_name, referee.first_name ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: referee).pluck(:school_id, :primary)
    assert_equal "colleague", Orm::TeacherProfile.find_by!(user: referee).joined_via
    assert_equal [ @teacher.id ], Orm::Referral.where(referee:).pluck(:referrer_id)
    sign_out

    # Wide screen: the counter is read on the sidebar card (UDR-0069 §3.6), the home's block being hidden from lg.
    sign_in_as @teacher
    visit teacher_home_path
    assert_selector "#sidebar_referral_count", text: "1"
    assert_selector "#sidebar_referral_count", text: I18n.t("#{INVITE}.count_label", count: 1)
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

      assert_toast I18n.t("shared.clipboard.copied_link")
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
