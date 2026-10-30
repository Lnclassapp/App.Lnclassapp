require "test_helper"

module Communication
  # UDR-0071 §3.2 and §3.4 (amendments of 2026-10-30): the team signs with the logo of the reader, the text holds ten
  # words on two lines, no « Modifiée ».
  class CardTest < ActionView::TestCase
    helper ComponentsHelper, Communication::IllustrationsHelper, Communication::MessagesHelper, BrandHelper

    Actor = Data.define(:role) do
      def teacher? = role == :teacher
    end


    Card = Queries::Communication::InboxQuery::MessageCard

    def card(author_role: :team, audio: false, body: "Texte court.", edited: false)
      Card.new(public_id: "abc123", title: "Rentrée", body:, illustration: "info", author_role:, gender: "female",
               last_name: "Kamaté", materials: [], anonymized: false, official: false, image: false, audio:, edited:, dismissed: false)
    end

    # current_actor et lnclass_app viennent des concerns du contrôleur ; ici, le lecteur de la carte.
    def render_card(viewer: nil, **)
      view.define_singleton_method(:current_actor) { viewer }
      view.define_singleton_method(:lnclass_app) { nil }
      render(partial: "communication/messages/card", locals: { card: card(**), context: :list, dismissible: false })
    end

    test "LA-1 — the team's signature carries the official logo, then « Lnclass »" do
      render_card

      assert_select "p img.size-5.shrink-0.rounded-sm.object-cover[alt=''][width='20'][height='20'][src*='logo/lnclass']"
      assert_select "p:has(img[src*='logo/lnclass'])", text: /Lnclass/
      assert_select "img[src*='lnclass/icon']", 0
    end

    test "the team's logo is the teacher's for a teacher reader" do
      render_card(viewer: Actor.new(role: :teacher))

      assert_select "p img[src*='logo/lnclass-teacher']"
    end

    test "the team's logo is the blue one for a student reader" do
      render_card(viewer: Actor.new(role: :student))

      assert_select "p img[src*='logo/lnclass-']"
      assert_select "img[src*='lnclass-teacher']", 0
    end

    test "the text holds ten words, then « … », and two lines at most" do
      render_card(body: "Un deux trois quatre cinq six sept huit neuf dix onze douze.")

      assert_select "p.line-clamp-2", text: "Un deux trois quatre cinq six sept huit neuf dix…"
    end

    test "a text of ten words or less is shown whole, escaped" do
      render_card(body: "Un <b>deux</b> trois quatre cinq six sept huit neuf dix")

      assert_select "p.line-clamp-2", text: "Un <b>deux</b> trois quatre cinq six sept huit neuf dix"
      assert_select "p.line-clamp-2 b", 0
    end

    test "an edited announcement is not marked « Modifiée »" do
      render_card(edited: true)

      assert_select "*", text: /Modifiée/, count: 0
    end

    test "LA-1 — an author's card has no logo" do
      render_card(author_role: :teacher)

      assert_select "img[src*='logo/lnclass']", 0
    end

    test "LA-7 — retired: a card with an audio has no « Télécharger » link and no download attribute" do
      render_card(audio: true)

      assert_select "div[data-controller='communication--audio']"
      assert_select "a[download]", 0
      assert_select "a[href*='download']", 0
      assert_select "a", text: "Télécharger", count: 0
    end
  end
end
