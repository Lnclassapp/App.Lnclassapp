require "application_system_test_case"

# AN-10, AN-12, AN-13, AN-18 (UDR-0071 §3.2, §3.4 to §3.7), in a real browser. On her home, Awa sees the carousel (direction,
# teachers, team), hides a card with its cross and « Annuler » gives it back; on « Toutes les annonces », a hidden message is
# marked « Masquée » and « Réafficher » gives it back; ▶ exists only on a message with an audio, plays it, and says when the
# phone cannot. At least one journey on a phone.
class Communication::StudentAnnouncementsTest < ApplicationSystemTestCase
  setup do
    lauriers = create_school(name: "Collège Les Lauriers")
    troisieme_b = create_classroom(school: lauriers, name: "3ème B")
    @awa = create_student(classroom: troisieme_b, first_name: "Awa")
    kouassi = create_teacher(school: lauriers, material: create_material(name: "SVT"), classrooms: [ troisieme_b ],
                             gender: "male", last_name: "Kouassi")
    @fiches = create_message(author: kouassi, title: "Nouvelles fiches", body: "Elles sont en ligne.", audience: "classrooms",
                             classrooms: [ troisieme_b ], published_at: 1.hour.ago)
    @devoirs = create_message(author: create_school_admin(school: lauriers, gender: "female", last_name: "Kamaté"),
                              title: "Devoirs communs", school: lauriers, published_at: 3.hours.ago)
    @rentree = create_message(author: create_team_member(second_factor: false), title: "Rentrée numérique", audience: "all",
                              published_at: 2.hours.ago)
    attach(@fiches, wav, "audio/wav")
  end

  # A short silent WAV (8 kHz, 8 bits, mono) that any Chrome plays.
  def wav(seconds: 0.3, rate: 8000)
    data = ([ 128 ] * (rate * seconds).to_i).pack("C*")
    [ "RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate, 1, 8, "data", data.bytesize ].pack("a4Va4a4VvvVVvva4V") + data
  end

  def attach(message, data, content_type)
    Repositories::Communication::AttachmentStore.new.attach(message_id: message.id, kind: :audio, io: StringIO.new(data),
                                                            content_type:, filename: "message")
  end

  def card(message) = find("#announcement_#{message.public_id}")
  def tc(key, **) = I18n.t("communication.#{key}", **)
  def cross(message) = %(button[aria-label="#{tc('card.dismiss', title: message.title)}"])
  def dismissed?(message) = Orm::MessageDismissal.exists?(message:, user: @awa)

  def carousel_titles = all("#student_home_announcements li article h3").map(&:text)
  def dot_classes = all("[data-communication--carousel-target=dot]", visible: :all).map { it[:class] }

  test "AN-10 — on her home, the carousel after « À faire »: the direction, the teacher, the team, then « Toutes les annonces »" do
    sign_in_as @awa

    assert_current_path student_home_path
    assert_equal [ "Devoirs communs", "Nouvelles fiches", "Rentrée numérique" ], carousel_titles
    within("#student_home_announcements") do
      assert_selector "[data-communication--carousel-target=pager].flex", visible: :visible
      click_on tc("inboxes.carousel.all")
    end
    assert_current_path announcements_path
    assert_equal [ "Nouvelles fiches", "Rentrée numérique", "Devoirs communs" ], all("#announcements article h3").map(&:text)
  end

  test "AN-12 — on her home, the cross takes the card out of the carousel, the focus goes to the band, « Annuler » brings it back" do
    sign_in_as @awa

    assert_no_page_reload do
      within("#student_home_announcements") { find(cross(@fiches)).click }

      assert_toast tc("dismissal.title")
      assert_equal [ "Devoirs communs", "Rentrée numérique" ], carousel_titles
      assert_equal "student_home_announcements_title", page.evaluate_script("document.activeElement.id")
      assert dismissed?(@fiches)

      within("#toasts") { click_on tc("dismissal.undo") }

      assert_selector "#student_home_announcements #{cross(@fiches)}"
      assert_equal [ "Devoirs communs", "Nouvelles fiches", "Rentrée numérique" ], carousel_titles
    end
    assert_not dismissed?(@fiches)
  end

  test "AN-10, AN-12 — on a phone, the band scrolls by itself, its dots follow the visible card; hidden, a card leaves it" do
    sign_in_as @awa

    with_mobile_viewport do
      visit student_home_path

      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"
      assert_match(/\bw-4\b/, dot_classes.first)
      page.execute_script("document.querySelector('[data-communication--carousel-target=track]').scrollLeft = 10000")
      assert_selector "[data-communication--carousel-target=dot]:last-child.w-4.bg-brand-strong"
      assert_match(/\bw-1\.5\b/, dot_classes.first)

      within("#student_home_announcements") { find(cross(@rentree)).click }
      assert_toast tc("dismissal.title")
      assert_equal [ "Devoirs communs", "Nouvelles fiches" ], carousel_titles
    end
  end

  test "AN-12 — Awa hides « Nouvelles fiches » with its cross, then « Annuler » gives it back, without reloading the page" do
    sign_in_as @awa
    visit announcements_path
    assert_equal [ "Nouvelles fiches", "Rentrée numérique", "Devoirs communs" ], all("#announcements article h3").map(&:text)

    assert_no_page_reload do
      card(@fiches).find(cross(@fiches)).click

      assert_toast tc("dismissal.title")
      within(card(@fiches)) do
        assert_text tc("card.dismissed")
        assert_button tc("card.restore")
        assert_no_selector cross(@fiches)
      end
      assert dismissed?(@fiches)

      within("#toasts") { click_on tc("dismissal.undo") }

      assert_no_selector "#toasts [data-controller=toast]"
      within(card(@fiches)) { assert_selector cross(@fiches) }
      assert_no_text tc("card.dismissed")
    end
    assert_not dismissed?(@fiches)
  end

  test "AN-12 — a hidden message is marked « Masquée »; « Réafficher » gives it back, without a toast" do
    dismiss_message(message: @fiches, user: @awa)
    sign_in_as @awa
    visit announcements_path

    within(card(@fiches)) do
      assert_text tc("card.dismissed")
      click_on tc("card.restore")

      assert_selector cross(@fiches)
      assert_no_text tc("card.dismissed")
    end
    assert_no_selector "#toasts [data-controller=toast]"
    assert_not dismissed?(@fiches)
  end

  test "AN-13, AN-18 — ▶ only on the message with an audio; it plays it, then offers to listen again" do
    sign_in_as @awa
    visit announcements_path

    within(card(@devoirs)) do
      assert_text "Mme Kamaté · Direction"
      assert_no_selector "button[aria-label^='Masquer']"
    end
    assert_no_selector "#announcement_#{@rentree.public_id} [data-controller='communication--audio']"

    within(card(@fiches)) do
      assert_text "M. Kouassi · SVT"
      find("button[aria-label='#{tc('audio.labels.new')}']").click

      assert_selector "button[data-state=played][aria-label='#{tc('audio.labels.played')}'].opacity-60", wait: 10
    end
    assert_equal({ @fiches.public_id => true }, JSON.parse(page.evaluate_script("localStorage.getItem('lnclass.announcements.played')")))

    visit announcements_path

    within(card(@fiches)) { assert_selector "button[data-state=played][aria-label='#{tc('audio.labels.played')}']" }
  end

  test "an audio the phone cannot play says so in its card, then the button is back at rest" do
    attach(@rentree, "ID3".b + "\x00".b * 64, "audio/mpeg")
    sign_in_as @awa
    visit announcements_path

    within(card(@rentree)) do
      find("button[aria-label='#{tc('audio.labels.new')}']").click

      assert_selector "[aria-live=polite]", text: tc("audio.unavailable"), wait: 10
      assert_selector "button[data-state=new]"
    end
  end

  test "AN-12 — on a phone: the cards stack, the page does not scroll sideways, the cross hides and « Annuler » undoes" do
    sign_in_as @awa

    with_mobile_viewport do
      visit announcements_path

      lefts = all("#announcements > li").map { it.evaluate_script("this.getBoundingClientRect().left") }
      assert_equal 1, lefts.uniq.size, "les cartes doivent s'empiler"
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth"), "la page défile en largeur"

      card(@fiches).find(cross(@fiches)).click
      assert_toast tc("dismissal.title")
      within(card(@fiches)) { assert_text tc("card.dismissed") }

      within("#toasts") { click_on tc("dismissal.undo") }
      within(card(@fiches)) { assert_selector cross(@fiches) }
    end
  end
end
