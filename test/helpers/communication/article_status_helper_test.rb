require "test_helper"

# UDR-0067 §3.2 : le badge d'état d'un article (liste de gestion, modale, bandeau d'aperçu de l'UDR-0066) et les entrées
# du menu ⋮ d'une ligne : Modifier, Aperçu ou Voir l'article, puis la transition permise par l'état.
module Communication
  class ArticleStatusHelperTest < ActionView::TestCase
    helper ComponentsHelper

    Row = Data.define(:public_id, :slug, :status)

    def menu(status)
      render html: article_menu_items(article: Row.new(public_id: "abcdefghijkmno", slug: "reviser-le-bepc", status:))
    end

    test "le badge nomme chaque état avec les tons du catalogue" do
      render html: safe_join(%w[draft published archived].map { article_status_badge(it) })

      assert_equal %w[Brouillon Publié Archivé], css_select("span.whitespace-nowrap").map(&:text)
      assert_equal({ "draft" => :warning, "published" => :success, "archived" => :neutral }, ArticleStatusHelper::ARTICLE_STATUS_TONES)
      assert_dom "span.bg-warning-soft", text: "Brouillon"
      assert_raises(KeyError) { article_status_badge("deleted") }
    end

    test "un brouillon : Modifier dans la modale, Aperçu, Publier" do
      menu("draft")

      assert_dom "div#article_transitions_abcdefghijkmno.contents[role=none]" do
        assert_dom "a[role=menuitem]", count: 3
        assert_dom "a:nth-of-type(1)[href='/teams/blog/abcdefghijkmno/edit'][data-turbo-frame=modal]", text: "Modifier"
        assert_dom "a:nth-of-type(2)[href='/blog/reviser-le-bepc']:not([data-turbo-method]):not([data-turbo-frame])", text: "Aperçu"
        assert_dom "a:nth-of-type(3)[href='/teams/blog/abcdefghijkmno/publish'][data-turbo-method=patch]", text: "Publier"
      end
    end

    test "un article publié : Modifier, Voir l'article, Archiver ; un archivé : Modifier, Aperçu, Remettre en ligne" do
      menu("published")

      assert_dom "a[role=menuitem]", count: 3
      assert_dom "a[href='/blog/reviser-le-bepc']", text: "Voir l'article"
      assert_dom "a[href='/teams/blog/abcdefghijkmno/archive'][data-turbo-method=patch]", text: "Archiver"

      menu("archived")

      assert_dom "a[href='/blog/reviser-le-bepc']", text: "Aperçu"
      assert_dom "a[href='/teams/blog/abcdefghijkmno/publish'][data-turbo-method=patch]", text: "Remettre en ligne"
    end

    test "chaque transition de Article::TRANSITIONS a son libellé, son icône et son action" do
      transitions = Entities::Communication::Article::TRANSITIONS.flat_map { |from, targets| targets.map { [ from, it ] } }

      assert_equal transitions.sort, ArticleStatusHelper::ARTICLE_TRANSITIONS.keys.sort
      assert_equal [ [ "publish", "check-circle", "publish" ], [ "archive", "archive-box", "archive" ], [ "republish", "arrow-uturn-up", "publish" ] ],
                   ArticleStatusHelper::ARTICLE_TRANSITIONS.values_at(%w[draft published], %w[published archived], %w[archived published])
    end
  end
end
