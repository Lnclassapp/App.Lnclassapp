require "test_helper"

# CP-01, CP-05 to CP-07 (ADR-0063, UDR-0050): « Inviter un collègue », on its page and on the teacher home: the personal
# link, WhatsApp, SMS, copy and native share, and the counter. Only a teacher of an active school sees the block.
# IE-06 (ADR-0083 §4.1, UDR-0079 §3.7): the personal link is /i/<token>, without the school's code.
class Identity::ReferralsControllerTest < ActionDispatch::IntegrationTest
  PAGE = "identity.referrals".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school)
    @token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
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
    assert_select "#invite_colleagues", text: /vos collègues de Lycée Classique d'Abidjan s'inscrivent avec votre établissement déjà rempli/
    assert_no_match(/code/i, css_select("#invite_colleagues").text)
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

  # RE-18, RE-19 (UDR-0069 §3.6): the sidebar of the teacher asks this page in the deferred frame « sidebar_referral »;
  # it receives the compact « Parrainage » card alone, without the shell, or the same frame empty when the invitation is
  # closed — never a 403, which the frame would show as an error.
  SIDEBAR_FRAME = "sidebar_referral".freeze

  def get_sidebar_card = get(teacher_invite_path, headers: { "Turbo-Frame" => SIDEBAR_FRAME })

  # The ids of a subtree, without those of the toasts kept in <template> by the copy button.
  def ids_within(selector)
    css_select("#{selector} [id]").reject { it.ancestors("template").any? }.map { it["id"] }
  end

  test "RE-19: the sidebar frame receives the « Parrainage » card alone, without the layout" do
    3.times { create_referral(referrer: @teacher) }
    sign_in_as @teacher

    get_sidebar_card

    assert_response :success
    assert_match(/\A\s*<turbo-frame id="sidebar_referral">/, response.body)
    assert_no_match(/<html|<head|<body|<aside|<main/, response.body)
    assert_select "turbo-frame", 1
    assert_select "turbo-frame#sidebar_referral section#sidebar_referral_card[aria-labelledby=sidebar_referral_title]" do
      assert_select "h2#sidebar_referral_title", text: "Parrainage"
      assert_select "span", text: I18n.t("#{PAGE}.ambassador.badge")
      assert_select "#sidebar_referral_count", text: "3 collègues inscrits grâce à vous"
      assert_select "a#sidebar_referral_link[href='#{link}'][title='#{link}']", text: link
      assert_select "#sidebar_referral_actions[data-controller='identity--share']" \
                    "[data-identity--share-url-value='#{teacher_referral_shares_path}'][data-identity--share-link-value='#{link}']" \
                    "[data-action='clipboard:copied->identity--share#recordCopy']" do |actions|
        assert_equal share_message, actions.first["data-identity--share-text-value"]
        assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode(share_message)}'][target=_blank][rel=noopener]" \
                      "[data-action='identity--share#record'][data-identity--share-channel-param=whatsapp]", text: "WhatsApp"
        assert_select "[data-controller=clipboard][data-clipboard-text-value='#{link}'] button[data-action='clipboard#copy']",
                      text: "Copier le lien"
        assert_select "a[href='#{teacher_invite_path}']", text: "Plus d'options"
      end
    end
    assert_select "#invite_colleagues, #referral_link, a[href^='sms:']", 0
  end

  test "RE-19: the counter of the card says none yet, then one colleague; no badge under 3 colleagues" do
    sign_in_as @teacher

    get_sidebar_card
    assert_select "#sidebar_referral_count", text: "Aucun collègue inscrit grâce à vous pour l'instant."
    assert_select "#sidebar_referral_card", text: /#{I18n.t("#{PAGE}.ambassador.badge")}/, count: 0

    create_referral(referrer: @teacher)
    get_sidebar_card
    assert_select "#sidebar_referral_count", text: "1 collègue inscrit grâce à vous"
  end

  test "RE-18: a teacher of a draft or inactive school receives the frame empty, in 200, never 403" do
    %w[draft inactive].each do |status|
      sign_in_as create_teacher(school: create_school(status:))

      get_sidebar_card

      assert_response :success, status
      assert_match(/\A\s*<turbo-frame id="sidebar_referral">\s*<\/turbo-frame>\s*\z/, response.body, status)
      sign_out
    end
  end

  # ADR-0076 §4.2, UDR-0069 §3.6 amended (chantier politique-cache, lot E1): the home, which reads the invitation already,
  # renders the card with the page in the permanent frame of the sidebar; another page of the space keeps the deferred
  # frame. A teacher of a draft or inactive school gets the same permanent frame on the home, empty.
  test "RE-19: the home renders the card in the permanent sidebar frame; another page defers it; a closed invitation leaves it empty" do
    sign_in_as @teacher

    get teacher_home_path
    assert_select "aside turbo-frame#sidebar_referral[data-turbo-permanent][target=_top]:not([src])", 1 do
      assert_select "#sidebar_referral_count", text: "Aucun collègue inscrit grâce à vous pour l'instant."
      assert_select "a#sidebar_referral_link[href='#{link}']", text: link
    end
    get teacher_classrooms_path
    assert_select "aside turbo-frame#sidebar_referral[data-turbo-permanent][target=_top][loading=lazy][src='#{teacher_invite_path}']", 1
    assert_select "#sidebar_referral_card", 0
    sign_out

    %w[draft inactive].each do |status|
      sign_in_as create_teacher(school: create_school(status:))

      get teacher_home_path

      assert_response :success, status
      assert_select "aside turbo-frame#sidebar_referral[data-turbo-permanent]:not([src])", 1, status
      assert_select "#sidebar_referral_card, #sidebar_referral_link", 0, status
      sign_out
    end
  end

  test "RE-19: every id of the card is prefixed sidebar_referral_ and none is shared with the invitation block" do
    sign_in_as @teacher
    get teacher_invite_path
    block = ids_within("#invite_colleagues")

    get_sidebar_card
    card = ids_within("turbo-frame#sidebar_referral")

    assert_includes block, "referral_link"
    assert_equal %w[sidebar_referral_card sidebar_referral_title sidebar_referral_count sidebar_referral_link
                    sidebar_referral_actions].sort, card.sort
    assert(card.all? { it.start_with?("sidebar_referral_") }, card.inspect)
    assert_empty card & block
  end

  test "the class selection page leads to the invitation" do
    sign_in_as @teacher

    get teacher_classrooms_path

    assert_select "a[href='#{teacher_invite_path}']", text: /#{I18n.t("classroom.teaching_selections.index.invite")}/
  end
end
