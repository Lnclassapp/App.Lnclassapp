require "test_helper"

# CP-01, CP-05 to CP-07 (ADR-0063, UDR-0050): « Inviter un collègue », on its page and on the teacher home: the personal
# link, WhatsApp, SMS, copy and native share, and the counter. Only a teacher of an active school sees the block.
# IE-06 (ADR-0083 §4.1, UDR-0079 §3.7): the links are /i/<token>, without the school's code.
# ME-26, ME-27 (ADR-0094 §11, MET-8): two links, the one of the current school, then the sponsor link without school.
class Identity::ReferralsControllerTest < ActionDispatch::IntegrationTest
  PAGE = "identity.referrals".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
    @token = Orm::TeacherSchool.find_by!(teacher: @teacher).invite_token
    @sponsor_token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
  end

  def link = teacher_invite_link_url(@token)
  def share_message = I18n.t("#{PAGE}.invite.message", school: "Lycée Classique d'Abidjan", link:)

  test "CP-01, CP-05: the page shows the personal link and the four ways to share it, with a ready message" do
    sign_in_as @teacher

    get teacher_invite_path

    assert_response :success
    assert_match %r{/i/#{@token}\z}, link
    assert_match(/\A\h{12}\z/, @token)
    assert_no_match(/k7m4qz|K7M-?4QZ|\/e\//i, response.body)
    assert_no_match(/#{@teacher.public_id}|#{@teacher.contact}/, link)
    assert_select "#invite_colleagues" do
      assert_select "a#referral_link[href='#{link}']", text: link
      assert_select "#referral_share_actions[data-controller='identity--share']" \
                    "[data-identity--share-url-value='#{teacher_referral_shares_path}'][data-identity--share-link-value='#{link}']"
      assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode(share_message)}'][target=_blank][rel=noopener]" \
                    "[data-action='identity--share#record'][data-identity--share-channel-param=whatsapp]",
                    text: I18n.t("#{PAGE}.invite.whatsapp")
      assert_select "a[href='sms:?body=#{ERB::Util.url_encode(share_message)}'][data-identity--share-channel-param=sms]"
      assert_select "[data-controller=clipboard][data-clipboard-text-value='#{link}'] " \
                    "button[data-action='clipboard#copy'][aria-label=\"#{I18n.t("#{PAGE}.invite.copy_label")}\"]"
      assert_select "button[hidden][data-identity--share-target=native][data-action='identity--share#native']"
      assert_select "#referral_count", text: I18n.t("#{PAGE}.invite.count", count: 0)
    end
    assert_includes share_message, "Lycée Classique d'Abidjan"
    # ADR-0083: an invited colleague has no code to look for any more.
    assert_select "#invite_colleagues h2", text: "Inviter un collègue de Lycée Classique d'Abidjan"
    assert_select "#invite_colleagues", text: /vos collègues de Lycée Classique d'Abidjan s'inscrivent avec l'établissement déjà rempli/
    assert_no_match(/code/i, css_select("#invite_colleagues").text)
  end

  test "ME-27: the page then shows the sponsor link, without school, and its ways to share it" do
    sign_in_as @teacher

    get teacher_invite_path

    sponsor_link = teacher_invite_link_url(@sponsor_token)
    message = I18n.t("#{PAGE}.sponsor.message", link: sponsor_link)
    assert_not_equal @token, @sponsor_token
    assert_select "#invite_colleagues + #invite_others"
    assert_select "#invite_others" do
      assert_select "h2", text: I18n.t("#{PAGE}.sponsor.title")
      assert_select "a#sponsor_link[href='#{sponsor_link}']", text: sponsor_link
      assert_select "#sponsor_share_actions[data-identity--share-link-value='#{sponsor_link}']"
      assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode(message)}'][data-identity--share-channel-param=whatsapp]"
      assert_select "[data-clipboard-text-value='#{sponsor_link}'] button[aria-label=\"#{I18n.t("#{PAGE}.sponsor.copy_label")}\"]"
    end
    assert_no_match "Lycée Classique", css_select("#invite_others").text
  end

  test "ME-26: in his second school, the first link is that school's" do
    second = create_school(name: "Collège Saint-Michel")
    token = add_teacher_school(@teacher, second).invite_token
    sign_in_as @teacher
    patch teacher_current_school_path, params: { school_public_id: second.public_id }

    get teacher_invite_path

    assert_select "#invite_colleagues h2", text: "Inviter un collègue de Collège Saint-Michel"
    assert_select "a#referral_link[href='#{teacher_invite_link_url(token)}']"
    assert_select "a#sponsor_link[href='#{teacher_invite_link_url(@sponsor_token)}']"
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

  # UDR enseignant §3.3 (mvp-teacher-student, Lot G) : la carte « Inviter un collègue » quitte l'accueil sous lg ; elle reste sur sa page.
  test "CP-05: the invitation block is on its own page, not on the teacher home; a teacher of a draft school has none" do
    sign_in_as @teacher
    get teacher_home_path

    assert_select "#invite_colleagues", 0
    get teacher_invite_path

    assert_select "#invite_colleagues a#referral_link[href='#{link}']"
    sign_out

    sign_in_as create_teacher(school: create_school(status: "draft"))
    get teacher_home_path
    assert_response :success
    assert_select "#invite_colleagues", 0
  end

  # Mvp-teacher-student, lot P0 (UDR enseignant §2) : « Inviter un collègue » n'est plus que dans la grille de l'accueil ; la barre
  # latérale n'a plus la carte « Parrainage », ni sur l'accueil, ni sur une autre page, ni pour un établissement fermé. Seule
  # la page reste servie à son adresse (le frame de la barre latérale et sa carte sont retirés).
  test "RE-19: the sidebar of the teacher has no « Parrainage » frame, on the home or on another page" do
    sign_in_as @teacher

    [ teacher_home_path, teacher_classrooms_path ].each do |path|
      get path

      assert_response :success, path
      assert_select "aside turbo-frame#sidebar_referral, aside #sidebar_referral_card, aside #sidebar_referral_link", 0, path
    end
    sign_out

    %w[draft inactive].each do |status|
      sign_in_as create_teacher(school: create_school(status:))

      get teacher_home_path

      assert_response :success, status
      assert_select "aside turbo-frame#sidebar_referral", 0, status
      sign_out
    end
  end

  # Mvp-teacher-student, lot L (maquette enseignant 05) : « Quelles classes enseignez-vous ? » ne porte plus « Inviter un
  # collègue » ; l'invitation part de l'accueil (case « Inviter », lot G).
  test "the class selection page no longer carries the invitation" do
    sign_in_as @teacher

    get teacher_classrooms_path

    assert_response :success
    assert_select "main a[href='#{teacher_invite_path}']", 0
  end
end
