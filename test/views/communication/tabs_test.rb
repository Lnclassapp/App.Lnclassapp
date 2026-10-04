require "test_helper"

module Communication
  # UDR-0056 §3.7 : les onglets par URL de la page « Annonces », un lien par onglet du rôle, aria-current sur le courant.
  class TabsTest < ActionView::TestCase
    TAB = "inline-flex min-h-tap items-center border-b-2 px-4 text-sm font-medium whitespace-nowrap".freeze

    def tabs(role:, current:) = render(partial: "communication/shared/tabs", locals: { role:, current: })
    def label(key) = I18n.t("communication.tabs.#{key}")

    def assert_tabs(expected, current:)
      assert_select "nav#announcement-tabs[aria-label=?]", label(:label) do
        assert_select "a", expected.size
        expected.each_with_index do |(key, href), index|
          assert_select "a:nth-of-type(#{index + 1})[href=?]", href, text: label(key)
        end
        assert_select "a[aria-current=page]", 1
        assert_select "a[aria-current=page].border-brand.text-ink", text: label(current)
        assert_select "a:not([aria-current]).border-transparent.text-mute", expected.size - 1
      end
    end

    test "l'enseignant : Reçues puis Mes annonces" do
      tabs(role: :teacher, current: :received)

      assert_tabs [ [ :received, announcements_path ], [ :mine, my_announcements_path ] ], current: :received
    end

    test "la direction : Reçues, Mes annonces, puis Enseignants (la modération)" do
      tabs(role: :school_admin, current: :moderation)

      assert_tabs [ [ :received, announcements_path ], [ :mine, my_announcements_path ], [ :school, moderated_announcements_path ] ],
                  current: :school
    end

    test "l'équipe : Mes annonces puis Toutes (la modération) ; un rôle peut venir en chaîne" do
      tabs(role: "team", current: "mine")

      assert_tabs [ [ :mine, my_announcements_path ], [ :all, moderated_announcements_path ] ], current: :mine
    end

    test "chaque onglet est une cible de 48 px, au focus visible, qui ne passe pas à la ligne" do
      tabs(role: :teacher, current: :mine)

      assert_select "nav#announcement-tabs.scrollbar-none.mb-5.flex.gap-1.overflow-x-auto.border-b.border-line"
      assert_select "nav a", 2 do |links|
        links.each { assert_includes it["class"], TAB }
        links.each { assert_includes it["class"], "focus-visible:outline-brand" }
      end
    end

    test "l'élève n'a aucun onglet : la nav n'est pas rendue" do
      tabs(role: :student, current: :received)

      assert_select "nav", 0
      assert_select "a", 0
    end
  end
end
