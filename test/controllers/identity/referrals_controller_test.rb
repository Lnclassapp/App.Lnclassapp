require "test_helper"

# CP-01, CP-05 to CP-07 (ADR-0063, UDR-0050): « Inviter un collègue », on its page and on the teacher home: the personal
# link, WhatsApp, SMS, copy and native share, and the counter. Only a teacher of an active school sees the block.
class Identity::ReferralsControllerTest < ActionDispatch::IntegrationTest
  PAGE = "identity.referrals".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
    @token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
  end

  def link = school_code_signup_url("k7m4qz", ref: @token)
  def share_message = I18n.t("#{PAGE}.invite.message", school: "Lycée Classique d'Abidjan", link:)

  test "CP-01, CP-05: the page shows the personal link and the four ways to share it, with a ready message" do
    sign_in_as @teacher

    get teacher_invite_path

    assert_response :success
    assert_match %r{/e/k7m4qz\?ref=[0-9a-f]{12}\z}, link
    assert_no_match(/#{@teacher.public_id}|#{@teacher.contact}/, link)
    assert_select "#invite_colleagues" do
      assert_select "a#referral_link[href='#{link}']", text: link
      assert_select "#referral_share_actions[data-controller='identity--share']" \
                    "[data-identity--share-url-value='#{teacher_referral_shares_path}'][data-identity--share-link-value='#{link}']"
      assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode(share_message)}'][target=_blank][rel=noopener]" \
                    "[data-action='identity--share#record'][data-identity--share-channel-param=whatsapp]",
                    text: I18n.t("#{PAGE}.invite.whatsapp")
      assert_select "a[href='sms:?body=#{ERB::Util.url_encode(share_message)}'][data-identity--share-channel-param=sms]"
      assert_select "button[data-action='identity--share#copy'][aria-label=\"#{I18n.t("#{PAGE}.invite.copy_label")}\"]"
      assert_select "button[hidden][data-identity--share-target=native][data-action='identity--share#native']"
      assert_select "#referral_count", text: I18n.t("#{PAGE}.invite.count", count: 0)
    end
    assert_includes share_message, "Lycée Classique d'Abidjan"
  end

  test "CP-06: the counter says how many colleagues signed up thanks to the teacher" do
    2.times { create_referral(referrer: @teacher) }
    sign_in_as @teacher

    get teacher_invite_path

    assert_select "#referral_count", text: I18n.t("#{PAGE}.invite.count", count: 2)
    assert_select "#invite_colleagues", text: /#{I18n.t("#{PAGE}.ambassador.badge")}/, count: 0
  end

  test "CP-15: from 3 referees, the block shows the « Ambassadeur » badge" do
    3.times { create_referral(referrer: @teacher) }
    sign_in_as @teacher

    get teacher_invite_path

    assert_select "#invite_colleagues", text: /#{I18n.t("#{PAGE}.ambassador.badge")}/
  end

  test "CP-07: a teacher of a draft school reads that the invitation is not open, without link" do
    sign_in_as create_teacher(school: create_school(status: "draft"))

    get teacher_invite_path

    assert_response :success
    assert_select "#invite_colleagues", 0
    assert_select "main", text: /#{I18n.t("#{PAGE}.show.closed_title")}/
  end

  test "CP-07: a student and the team are refused in 403" do
    [ create_student(classroom: create_classroom), create_team_member ].each do |user|
      sign_in_as user
      get teacher_invite_path

      assert_response :forbidden
      sign_out
    end
  end

  test "CP-05: the teacher home ends with the block; a teacher of a draft school has none" do
    sign_in_as @teacher
    get teacher_home_path

    assert_select "#invite_colleagues a#referral_link[href='#{link}']"
    sign_out

    sign_in_as create_teacher(school: create_school(status: "draft"))
    get teacher_home_path
    assert_response :success
    assert_select "#invite_colleagues", 0
  end

  test "the class selection page leads to the invitation" do
    sign_in_as @teacher

    get teacher_classrooms_path

    assert_select "a[href='#{teacher_invite_path}']", text: /#{I18n.t("classroom.teaching_selections.index.invite")}/
  end
end
