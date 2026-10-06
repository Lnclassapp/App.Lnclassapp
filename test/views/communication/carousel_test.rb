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
               material_name: "SVT", anonymized: false, official: author_role == :school_admin, image: false, audio: false,
               edited: false, dismissed: false)
    end

    def carousel(cards, **) = render(partial: "communication/messages/carousel", locals: { carousel: Carousel.new(cards:, any_readable: true), ** })
    def all_link = I18n.t("communication.inboxes.carousel.all")

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

    test "AN-22 — the band leads to « Toutes les annonces »" do
      carousel([ card("a", "Une") ])

      assert_select "p.flex.justify-end a.inline-flex.min-h-tap.text-brand-strong[href=?]", announcements_path, text: all_link do
        assert_select "svg"
      end
    end

    test "AN-12 — every message dismissed: neither band nor dots, the link alone" do
      carousel([])

      assert_select "section#student_home_announcements" do
        assert_select "ul", 0
        assert_select "[data-communication--carousel-target=pager]", 0
        assert_select "a[href=?]", announcements_path, text: all_link
      end
    end

    # UDR-0071, amendment of 2026-10-06: the student's home has no « Toutes les annonces »; the teacher's and the
    # direction's homes keep it (default).
    test "link: false — the band of the student leads nowhere else" do
      carousel([ card("a", "Une") ], link: false)

      assert_select "section#student_home_announcements:not([hidden])" do
        assert_select "li article h3", "Une"
      end
      assert_select "a[href=?]", announcements_path, 0
    end

    test "link: false, every message dismissed: the section stays in the page, hidden, as the target of « Annuler »" do
      carousel([], link: false)

      assert_select "section#student_home_announcements[hidden]" do
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
