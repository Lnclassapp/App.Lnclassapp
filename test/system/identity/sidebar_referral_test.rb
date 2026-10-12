require "application_system_test_case"

# RE-19 (UDR-0069 §3.6, ADR-0063): on a wide screen, the sidebar of a teacher of an active school shows the « Parrainage »
# card on every page of the space but the invitation page itself; a share from the card is counted by the server as from
# that page. On a 390 px phone the sidebar is hidden: the frame is never requested.
# ADR-0076 §4.2: the home renders the card with the page, and a Turbo visit keeps the card already loaded (permanent
# frame): only a page reached by a full load asks the invitation page for it.
class Identity::SidebarReferralTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    @teacher = create_teacher(school: @school, first_name: "Aya")
    @token = Orm::TeacherProfile.find_by!(user: @teacher).referral_token
    3.times { create_referral(referrer: @teacher) }
  end

  def shares = Orm::ReferralShare.where(user: @teacher).order(:id).pluck(:channel)

  # How many times the browser asked the invitation page (the src of the frame) since this document loaded, after two
  # frames of rendering: the lazy frame is asked as soon as its observer sees it. A Turbo visit keeps the document.
  def invite_page_requests
    page.evaluate_async_script(<<~JS, teacher_invite_path)
      const [path, done] = arguments
      requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(() => {
        done(performance.getEntriesByType("resource").filter((entry) => new URL(entry.name).pathname === path).length)
      }, 100)))
    JS
  end

  def invite_page_requested? = invite_page_requests.positive?

  test "RE-19: on a wide screen the card shows in the sidebar of each page; a WhatsApp share there is counted" do
    sign_in_as @teacher
    visit teacher_home_path

    within "aside turbo-frame#sidebar_referral[data-turbo-permanent]" do
      assert_selector "#sidebar_referral_card h2", text: "Parrainage"
      assert_selector "#sidebar_referral_count", text: "3 collègues inscrits grâce à vous"
      assert_text "Ambassadeur"
      assert_selector "a#sidebar_referral_link", text: %r{/i/#{@token}\z} # IE-06 : sans le code d'établissement
      assert_button "Copier le lien"
      new_window = window_opened_by { click_on "WhatsApp" }
      new_window.close
    end
    assert_not invite_page_requested?, "l'accueil a redemandé la carte qu'il rend avec la page"
    growth_shot("1280-barre-laterale-parrainage")
    Timeout.timeout(10) { sleep 0.1 until shares == %w[whatsapp] }

    visit teacher_classrooms_path
    assert_selector "aside turbo-frame#sidebar_referral[complete] #sidebar_referral_card", text: "Ambassadeur"
    assert_equal 1, invite_page_requests

    within("aside nav") { click_on "Accueil" }
    assert_selector "h1", text: "Bonjour, Aya"
    assert_selector "aside turbo-frame#sidebar_referral #sidebar_referral_card", text: "Ambassadeur"
    within("aside nav") { click_on "Cours" }
    assert_current_path courses_path
    assert_selector "aside turbo-frame#sidebar_referral #sidebar_referral_card", text: "Ambassadeur"
    assert_equal 1, invite_page_requests, "une visite Turbo a redemandé la carte déjà chargée"

    visit teacher_invite_path
    assert_selector "#invite_colleagues a#referral_link"
    assert_no_selector "turbo-frame#sidebar_referral, #sidebar_referral_card", visible: :all
  end

  test "RE-19: on a 390 px phone the sidebar frame is never requested" do
    with_mobile_viewport do
      sign_in_as @teacher
      visit teacher_home_path

      assert_selector "#invite_colleagues a#referral_link"
      assert_no_selector "#sidebar_referral_card"
      assert_not invite_page_requested?

      visit teacher_classrooms_path
      assert_selector "turbo-frame#sidebar_referral:not([complete])", visible: :hidden
      assert_not invite_page_requested?, "le frame de la barre latérale a été demandé à 390 px"
      assert_no_selector "#sidebar_referral_card", visible: :all
    end
  end
end
