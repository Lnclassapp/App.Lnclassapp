require "test_helper"

module Communication
  # UDR-0071 §3.2 and §3.4 (amendment of 2026-10-30): the team signs with the official logo; « Télécharger » sits under ▶.
  class CardTest < ActionView::TestCase
    helper ComponentsHelper, Communication::IllustrationsHelper, Communication::MessagesHelper

    Card = Queries::Communication::InboxQuery::MessageCard

    def card(author_role: :team, audio: false)
      Card.new(public_id: "abc123", title: "Rentrée", body: "Texte court.", illustration: "info", author_role:, gender: "female",
               last_name: "Kamaté", materials: [], anonymized: false, official: false, image: false, audio:, edited: false, dismissed: false)
    end

    def render_card(**) = render(partial: "communication/messages/card", locals: { card: card(**), context: :list, dismissible: false })

    test "LA-1 — the team's signature carries the official logo, then « Lnclass »" do
      render_card

      assert_select "p img.size-5.shrink-0.rounded-sm.object-cover[alt=''][width='20'][height='20'][src*='logo/lnclass']"
      assert_select "img[src*='lnclass/icon']", 0
    end

    test "LA-1 — an author's card has no logo" do
      render_card(author_role: :teacher)

      assert_select "img[src*='logo/lnclass']", 0
    end

    test "LA-7 — with an audio, « Télécharger » sits under ▶, downloads without Turbo, and is named after the title" do
      render_card(audio: true)

      assert_select "div[data-controller='communication--audio']" do
        assert_select "a.min-h-tap.text-school.underline[href=?][download][data-turbo=false][aria-label=?]",
                      announcement_file_path("abc123", kind: "audio", download: 1),
                      I18n.t("communication.audio.download_label", title: "Rentrée"), text: I18n.t("communication.audio.download") do
          assert_select "svg[aria-hidden=true]"
        end
      end
    end

    test "LA-7 — without an audio, no « Télécharger »" do
      render_card

      assert_select "a[download]", 0
      assert_select "a", text: I18n.t("communication.audio.download"), count: 0
    end
  end
end
