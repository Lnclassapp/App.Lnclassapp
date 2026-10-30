require "test_helper"

module Communication
  # UDR-0071 §3.5: the announcements of the student's home, in a native scroll-snap band. Its plugging into the new
  # student home (UDR-0058, on Develop) comes after the merge of Develop: the partial is tested alone here.
  class CarouselTest < ActionView::TestCase
    helper ComponentsHelper, Communication::IllustrationsHelper, Communication::MessagesHelper

    Card = Queries::Communication::InboxQuery::MessageCard
    Carousel = Queries::Communication::InboxQuery::Carousel

    def card(public_id, title, author_role: :teacher)
      Card.new(public_id:, title:, body: "Texte court.", illustration: "info", author_role:, gender: "female", last_name: "Kamaté",
               materials: [ Queries::Identity::TeacherMaterialsQuery::MaterialTag.new(id: 1, name: "SVT", shortname: "SVT",
                                                                                      category: "science", slug: "svt") ],
               anonymized: false, official: author_role == :school_admin, image: false, audio: false,
               edited: false, dismissed: false)
    end

    def carousel(cards, **) = render(partial: "communication/messages/carousel", locals: { carousel: Carousel.new(cards:, any_readable: true), ** })

    test "AN-10 — a section titled for screen readers, one card per item of the band, in the given order" do
      carousel([ card("d", "Devoirs communs", author_role: :school_admin), card("f", "Nouvelles fiches"), card("r", "Rentrée", author_role: :team) ])

      assert_select "section#student_home_announcements.min-w-0.rounded-card.bg-mist.p-2\\.5[aria-labelledby=student_home_announcements_title]" \
                    "[data-controller='communication--carousel']" do
        assert_select "h2#student_home_announcements_title.sr-only[tabindex='-1']", I18n.t("shared.home.sections.announcements.title")
        assert_select "ul.scrollbar-none.flex.snap-x.snap-mandatory.gap-2.overflow-x-auto[data-communication--carousel-target=track]" do
          assert_select "> li.shrink-0.basis-11\\/12.snap-start", 3
        end
        assert_equal [ "Devoirs communs", "Nouvelles fiches", "Rentrée" ], css_select("li article h3").map(&:text)
      end
      assert_select "section[data-communication--carousel-refocus-value]", 0
    end

    # CA-D10 (Lot O1): from lg two cards are in view, side by side, for every role; only the student's band (student: true)
    # becomes a white card on the mist page.
    test "from lg, two cards are in view without a gap that would push the second out of the band, for every role" do
      carousel([ card("a", "Une"), card("b", "Deux"), card("c", "Trois") ])

      assert_select "ul.lg\\:-mx-1\\.5.lg\\:gap-0" do
        assert_select "> li.sm\\:basis-1\\/2.lg\\:px-1\\.5", 3
      end
      assert_select "section#student_home_announcements.bg-mist.p-2\\.5"
      assert_select "section#student_home_announcements[class*='lg:bg-paper']", 0
    end

    test "student: true — from lg the band is a white card with a line, on the mist page" do
      carousel([ card("a", "Une") ], student: true)

      assert_select "section#student_home_announcements.bg-mist.lg\\:border.lg\\:border-line.lg\\:bg-paper.lg\\:p-4.lg\\:shadow-card"
    end

    test "AN-13 — the cross on every card but the official one" do
      carousel([ card("d", "Devoirs communs", author_role: :school_admin), card("f", "Nouvelles fiches"), card("r", "Rentrée", author_role: :team) ])

      assert_select "#announcement_d form", 0
      assert_select "#announcement_f form[action=?] button[aria-label=?]", announcement_dismissal_path("f"),
                    I18n.t("communication.card.dismiss", title: "Nouvelles fiches")
      assert_select "#announcement_r form[action=?]", announcement_dismissal_path("r")
    end

    test "the pager: one hidden dot per card, the first one active; the controller shows it from two cards" do
      carousel([ card("a", "Une"), card("b", "Deux") ])

      assert_select "div.hidden.justify-center.gap-1\\.5.pt-2[aria-hidden=true][data-communication--carousel-target=pager]" do
        assert_select "span[data-communication--carousel-target=dot]", 2
        assert_select "span:first-child.h-1\\.5.w-4.rounded-full.bg-brand-strong"
        assert_select "span:last-child.h-1\\.5.w-1\\.5.rounded-full.bg-line"
      end
    end

    # LA-8: no « Toutes les annonces » under the band, for any role (the "Reçues" tab keeps its own address).
    test "AN-22, LA-8 — the band has no « Toutes les annonces » link, by default either" do
      carousel([ card("a", "Une") ])

      assert_select "a[href=?]", announcements_path, 0
      assert_select "p.flex.justify-end", 0
      assert_no_match(/Toutes les annonces/, rendered)
    end

    test "AN-12 — every message dismissed, not for the student: neither band, dots nor link" do
      carousel([])

      assert_select "section#student_home_announcements" do
        assert_select "ul", 0
        assert_select "[data-communication--carousel-target=pager]", 0
        assert_select "a", 0
      end
    end

    # UDR-0071, amendments of 2026-10-06 and 2026-10-30: no « Toutes les annonces » anywhere; `student:` only commands
    # the white card from lg and the sr-only state.
    test "student: true — the band of the student leads nowhere else" do
      carousel([ card("a", "Une") ], student: true)

      assert_select "section#student_home_announcements.bg-mist:not(.sr-only)" do
        assert_select "li article h3", "Une"
      end
      assert_select "a[href=?]", announcements_path, 0
    end

    test "student: true, every message dismissed: the section stays for screen readers only, target of « Annuler » and of the focus" do
      carousel([], student: true, refocus: true)

      assert_select "section#student_home_announcements.sr-only:not([hidden])[data-communication--carousel-refocus-value=true]" do
        assert_select "h2#student_home_announcements_title[tabindex='-1']"
        assert_select "p", I18n.t("communication.inboxes.carousel.all_dismissed")
        assert_select "ul", 0
        assert_select "a", 0
      end
    end

    test "rendered by a dismissal, the carousel asks its controller to bring the focus back to its title" do
      carousel([ card("a", "Une") ], refocus: true)

      assert_select "section#student_home_announcements[data-communication--carousel-refocus-value=true]"
    end
  end
end
