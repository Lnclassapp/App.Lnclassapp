require "application_system_test_case"

# AN-22 and the nominal journey of the PRD (§3), in a real browser, end to end, then its error path on the same announcement.
# On his phone, M. Kouassi opens « Annonces » from his bottom bar and publishes « Nouvelles fiches » for 3ème B and 3ème C with
# an mp3. On hers, Awa finds the announcement of Mme Kamaté first (official badge, no cross), then M. Kouassi's card with ▶
# on his mp3; she hides it with its cross and « Toutes les annonces » shows it « Masquée ». Fatou withdraws it from
# « Toutes », behind its confirmation: the line leaves the list.
#
# One journey, one sign-in per step: the chantier has 15 s of system suite (ADR-0069 §9). What another test already plays
# stays there: in the browser, ▶ playing an audio and « Annuler » after a hide (AN-12, AN-13, student_announcements_test),
# the team's « Annonces » link (AN-22, role_homes_test); at controller level, the direction's form (AN-03,
# authored_messages_controller_test), the 404 of the audio for a student of 3ème A (AN-09, message_files_controller_test),
# and, once withdrawn, Awa reading it no more, its audio in 404 and « Retirée » without actions for M. Kouassi (AN-16,
# message_withdrawals_controller_test).
class Communication::AnnouncementsJourneyTest < ApplicationSystemTestCase
  AUDIO = "announcements/nouvelles-fiches.mp3".freeze
  BOTTOM_BAR = "nav.fixed.bottom-0".freeze

  setup do
    @lauriers = create_school(name: "Collège Les Lauriers")
    @troisieme_b, @troisieme_c = [ "3ème B", "3ème C" ].map { create_classroom(school: @lauriers, name: it) }
    @kouassi = create_teacher(school: @lauriers, material: create_material(name: "SVT"), classrooms: [ @troisieme_b, @troisieme_c ],
                              gender: "male", last_name: "Kouassi")
    @awa = create_student(classroom: @troisieme_b, first_name: "Awa")
    @devoirs = create_message(author: create_school_admin(school: @lauriers, gender: "female", last_name: "Kamaté"),
                              title: "Devoirs communs", school: @lauriers, published_at: 3.hours.ago)
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def tc(key, **) = I18n.t("communication.#{key}", **)
  def field(attribute) = Dtos::Communication::MessageInput.human_attribute_name(attribute)
  def card(announcement) = "#announcement_#{announcement.public_id}"
  def cross(announcement) = %(button[aria-label="#{tc('card.dismiss', title: announcement.title)}"])
  def carousel_titles = all("#student_home_announcements li article h3").map(&:text)

  # On a phone, as a finger would: the element first brought into view, out of the fixed bottom bar and, in the carousel,
  # swiped to (without it, Chrome refuses the click and Capybara retries for a second).
  def tap(node)
    page.execute_script("arguments[0].scrollIntoView({ behavior: 'instant', block: 'center', inline: 'start' })", node)
    node.click
  end

  test "AN-22, AN-05, AN-12, AN-16 — M. Kouassi publishes for 3ème B and 3ème C with an audio; Awa hides it; Fatou withdraws it" do
    fiches = with_mobile_viewport do
      publish_as_kouassi
      read_and_hide_as_awa
    end

    sign_in_as create_team_member(first_name: "Fatou")
    visit moderated_announcements_path
    within("#moderated_announcement_#{fiches.public_id}") do
      click_on tc("moderations.moderated_message.withdraw")
      within("dialog[open]") { click_on tc("moderations.moderated_message.withdraw") }
    end

    assert_toast tc("message_withdrawals.create.withdrawn")
    assert_no_selector "#moderated_announcement_#{fiches.public_id}"
    assert_equal "withdrawn", fiches.reload.status
  end

  private

  # PRD §3, steps 1 to 3: from the bottom bar, « Mes annonces », « Nouvelle annonce »; the form, then « Publiée ».
  def publish_as_kouassi
    sign_in_as @kouassi
    within(BOTTOM_BAR) { click_link tn(:announcements) }

    assert_current_path announcements_path
    within(BOTTOM_BAR) { assert_selector "a[aria-current=page]", text: tn(:announcements) }
    within("#announcement-tabs") { click_link tc("tabs.mine") }
    click_on tc("authored_messages.index.new"), match: :first
    fill_in field(:title), with: "Nouvelles fiches"
    fill_in field(:body), with: "Les fiches du chapitre 3 sont en ligne. Le détail est dans l'audio."
    tap find("label", text: tc("illustrations.sheets"))
    [ "3ème B", "3ème C" ].each { tap find("label", text: it) }
    attach_file field(:audio), file_fixture(AUDIO)
    tap find_button(tc("authored_messages.form.publish"))

    assert_current_path my_announcements_path
    assert_toast tc("authored_messages.saved.published")
    within("#my_announcements") { assert_text "3ème B, 3ème C · Publiée le" }
    sign_out
  end

  # PRD §3, steps 4 and 5: the carousel (direction first, official, no cross; then the card with ▶ on the mp3), the cross,
  # and « Toutes les annonces ». Returns the announcement.
  def read_and_hide_as_awa
    fiches = Orm::Message.find_by!(title: "Nouvelles fiches")
    sign_in_as @awa

    assert_current_path student_home_path
    assert_equal [ "Devoirs communs", "Nouvelles fiches" ], carousel_titles
    within(card(@devoirs)) do
      assert_text "Mme Kamaté · Direction"
      assert_selector ".sr-only", text: tc("card.official"), visible: :all
      assert_no_selector "button[aria-label^='Masquer']"
    end
    within(card(fiches)) do
      assert_text "M. Kouassi · SVT"
      assert_selector "button[data-state=new][aria-label='#{tc('audio.labels.new')}']"
      assert_selector "audio[preload=none][src='#{announcement_file_path(fiches.public_id, kind: 'audio')}']", visible: :all
    end

    assert_no_page_reload do
      within("#student_home_announcements") { tap find(cross(fiches)) }

      assert_toast tc("dismissal.title")
      assert_no_selector "#student_home_announcements #{card(fiches)}"
      assert_equal [ "Devoirs communs" ], carousel_titles
    end
    within("#student_home_announcements") { click_on tc("inboxes.carousel.all") }

    assert_current_path announcements_path
    within(card(fiches)) { assert_text tc("card.dismissed") }
    sign_out
    fiches
  end
end
