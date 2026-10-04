require "test_helper"

# UDR-0071 §3.2 and §3.7: « Toutes les annonces » of the student and « Reçues » of the teacher and the direction, the
# readable messages newest first, each as its card; the team is sent to « Mes annonces », a visitor to « Se connecter ».
module Communication
  class InboxesControllerTest < ActionDispatch::IntegrationTest
    AUDIO = ("ID3".b + "\x00".b * 64).freeze

    setup do
      @lauriers = create_school(name: "Collège Les Lauriers")
      @troisieme_b = create_classroom(school: @lauriers, name: "3ème B")
      @awa = create_student(classroom: @troisieme_b, first_name: "Awa")
      @kouassi = create_teacher(school: @lauriers, material: create_material(name: "SVT"), classrooms: [ @troisieme_b ],
                                gender: "male", last_name: "Kouassi")
      @kamate = create_school_admin(school: @lauriers, gender: "female", last_name: "Kamaté")
      @fatou = create_team_member
    end

    def tl(key, **) = I18n.t("communication.inboxes.show.#{key}", **)
    def card_id(message) = "#announcement_#{message.public_id}"
    def dismiss_label(title) = I18n.t("communication.card.dismiss", title:)

    def fiches(**) = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @troisieme_b ], **)
    def devoirs(**) = create_message(author: @kamate, title: "Devoirs communs", school: @lauriers, **)
    def rentree(**) = create_message(author: @fatou, title: "Rentrée numérique", audience: "all", **)

    def attach(message, kind, data, content_type)
      Repositories::Communication::AttachmentStore.new.attach(message_id: message.id, kind:, io: StringIO.new(data),
                                                              content_type:, filename: "fichier")
    end

    test "AN-10 — « Toutes les annonces » lists every readable message of the student, newest first, without tabs" do
      titles = [ [ "Devoirs communs", 5 ], [ "Fiches 1", 3 ], [ "Fiches 2", 2 ], [ "Fiches 3", 1 ], [ "Rentrée", 4 ], [ "Concours", 6 ] ]
      titles.each do |title, hours|
        author = { "D" => @kamate, "F" => @kouassi, "R" => @fatou, "C" => @fatou }.fetch(title[0])
        audience = author == @kouassi ? "classrooms" : "students"
        create_message(author:, title:, audience:, classrooms: (author == @kouassi ? [ @troisieme_b ] : []),
                       school: (@lauriers unless author == @kouassi), published_at: hours.hours.ago)
      end
      sign_in_as @awa

      get announcements_path

      assert_response :success
      assert_select "title", "#{tl('page_title.student')} · Élève · Lnclass"
      assert_select "h1", tl("title")
      assert_select "*", text: tl("subtitle.student")
      assert_select "nav#announcement-tabs", 0
      assert_select "ul#announcements.grid.gap-3 > li > article h3", 6
      assert_equal [ "Fiches 3", "Fiches 2", "Fiches 1", "Rentrée", "Devoirs communs", "Concours" ],
                   css_select("ul#announcements article h3").map(&:text)
    end

    test "AN-01, AN-03, AN-05 — each card is signed, the official one with its badge and without a cross" do
      fiche = fiches
      devoir = devoirs
      rentre = rentree
      sign_in_as @awa

      get announcements_path

      assert_select "#{card_id(fiche)}[aria-labelledby=?]", "announcement_#{fiche.public_id}_title" do
        assert_select "h3#announcement_#{fiche.public_id}_title", "Nouvelles fiches"
        assert_select "p span.truncate", "M. Kouassi · SVT"
        assert_select "form.absolute.top-0.right-0[action=?] button[aria-label=?]", announcement_dismissal_path(fiche.public_id),
                      dismiss_label("Nouvelles fiches")
        assert_select ".sr-only", 0
      end
      assert_select card_id(devoir) do
        assert_select "p span.truncate", "Mme Kamaté · Direction"
        assert_select "span.sr-only", I18n.t("communication.card.official")
        assert_select "svg.text-brand-strong"
        assert_select "form", 0
      end
      assert_select card_id(rentre) do
        assert_select "p img[alt='']"
        assert_select "p span", "Lnclass"
      end
    end

    test "AN-12 — a dismissed card is marked « Masquée », with « Réafficher » instead of the cross" do
      fiche = fiches
      dismiss_message(message: fiche, user: @awa)
      sign_in_as @awa

      get announcements_path

      assert_select card_id(fiche) do
        assert_select "span", I18n.t("communication.card.dismissed")
        assert_select "form[action=?] input[name=_method][value=delete]", announcement_dismissal_path(fiche.public_id)
        assert_select "form button", I18n.t("communication.card.restore")
        assert_select "button[aria-label]", 0
      end
    end

    test "AN-14 (display) — an edited message is marked « Modifiée »" do
      fiches(edited_at: 5.minutes.ago)
      sign_in_as @awa

      get announcements_path

      assert_select "article span", I18n.t("communication.card.edited")
    end

    test "AN-18 — an image replaces the illustration; only a card with an audio has the ▶ button" do
      with_files = fiches
      attach(with_files, :image, file_fixture("photos/photo.png").binread, "image/png")
      attach(with_files, :audio, AUDIO, "audio/mpeg")
      plain = rentree
      sign_in_as @awa

      get announcements_path

      assert_select card_id(with_files) do
        assert_select "img.size-16.rounded-ln.object-cover[src=?][alt=''][loading=lazy][decoding=async]",
                      announcement_file_path(with_files.public_id, kind: "image")
        assert_select "svg[viewBox='0 0 64 64']", 0
        assert_select "div[data-controller='communication--audio'][data-communication--audio-key-value=?]", with_files.public_id do
          assert_select "button[type=button][data-state=new][aria-label=?][data-action='communication--audio#toggle']",
                        I18n.t("communication.audio.labels.new")
          assert_select "audio[preload=none][src=?][data-communication--audio-target=player]",
                        announcement_file_path(with_files.public_id, kind: "audio")
        end
        assert_match announcement_file_path(with_files.public_id, kind: "audio"), css_select("noscript").sole.inner_html
        assert_select "p[aria-live=polite][data-communication--audio-target=status]", text: ""
      end
      assert_select card_id(plain) do
        assert_select "svg[viewBox='0 0 64 64'][aria-hidden=true]"
        assert_select "[data-controller='communication--audio']", 0
        assert_select "audio", 0
      end
    end

    test "the ▶ button carries its labels and its failure message for the Stimulus controller" do
      attach(fiches, :audio, AUDIO, "audio/mpeg")
      sign_in_as @awa

      get announcements_path

      audio = css_select("[data-controller='communication--audio']").sole
      assert_equal I18n.t("communication.audio.labels").stringify_keys, JSON.parse(audio["data-communication--audio-labels-value"])
      assert_equal I18n.t("communication.audio.unavailable"), audio["data-communication--audio-unavailable-value"]
    end

    test "AN-20 — a text with a script is shown as such, never run" do
      create_message(author: @fatou, title: "<b>Titre</b>", body: "<script>alert(1)</script>", audience: "all")
      sign_in_as @awa

      get announcements_path

      assert_select "article p", "<script>alert(1)</script>"
      assert_select "article h3", "<b>Titre</b>"
      assert_select "article script", 0
      assert_select "article b", 0
    end

    test "AN-08, AN-19 — an ended or an archived message is not listed" do
      fiches(published_at: 31.days.ago, ends_at: 1.minute.ago)
      devoirs(status: "archived")
      create_message(author: @fatou, title: "Rentrée numérique", audience: "all")
      sign_in_as @awa

      get announcements_path

      assert_equal [ "Rentrée numérique" ], css_select("ul#announcements article h3").map(&:text)
    end

    test "AN-11 — no readable message: « Aucune annonce pour le moment. », for the student" do
      sign_in_as @awa

      get announcements_path

      assert_select "ul#announcements", 0
      assert_select "h2, h3, p", text: tl("empty.title")
      assert_select "p", text: tl("empty.description.student")
    end

    test "AN-05 — the teacher reads in « Reçues » what is for teachers, never a message for classrooms" do
      fiches
      create_message(author: @kamate, title: "Conseil de classe", audience: "teachers", school: @lauriers)
      create_message(author: @fatou, title: "Formation", audience: "teachers")
      sign_in_as @kouassi

      get announcements_path

      assert_response :success
      assert_select "title", "#{tl('page_title.adult')} · Enseignant · Lnclass"
      assert_select "*", text: tl("subtitle.adult")
      assert_select "nav#announcement-tabs a[aria-current=page][href=?]", announcements_path, I18n.t("communication.tabs.received")
      assert_equal [ "Conseil de classe", "Formation" ], css_select("ul#announcements article h3").map(&:text).sort
      assert_select "article form", 0
    end

    test "AN-02 — the direction reads in « Reçues » what is for directions; empty, the adult text" do
      create_message(author: @fatou, title: "Concours de maths", school: @lauriers)
      sign_in_as @kamate

      get announcements_path

      assert_select "nav#announcement-tabs a", 3
      assert_select "article", 0
      assert_select "p", text: tl("empty.description.adult")
    end

    test "AN-03 — the direction reads in « Reçues » what is for the directions of its school, and nothing of another school" do
      create_message(author: @fatou, title: "Réunion des directions", audience: "school_admins", school: @lauriers)
      create_message(author: @fatou, title: "Réunion à Bouaké", audience: "school_admins", school: create_school)
      sign_in_as @kamate

      get announcements_path

      assert_equal [ "Réunion des directions" ], css_select("ul#announcements article h3").map(&:text)
    end

    test "twenty cards per page, then the pagination" do
      21.times { |index| create_message(author: @fatou, title: "Annonce #{index}", audience: "all", published_at: (index + 1).minutes.ago) }
      sign_in_as @awa

      get announcements_path

      assert_select "ul#announcements > li", 20
      assert_select "a[href=?]", "#{announcements_path}?page=2"

      get announcements_path(page: 2)

      assert_select "ul#announcements > li", 1
      assert_select "article h3", "Annonce 20"
    end

    test "the team is sent to « Mes annonces »" do
      sign_in_as @fatou

      get announcements_path

      assert_redirected_to my_announcements_path
    end

    test "AN-22 — a visitor is sent to « Se connecter »" do
      get announcements_path

      assert_redirected_to new_session_path
    end
  end
end
