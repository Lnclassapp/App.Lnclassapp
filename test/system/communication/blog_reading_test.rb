require "application_system_test_case"

# UDR-0064 §3 (lecture au téléphone, colonne de 390 px) : un titre d'article qui porte un mot plus large que l'écran
# (« Anticonstitutionnellement ») revient à la ligne au lieu de faire défiler la page sur le côté, sur la page de
# l'article, dans les cartes de /blog, sur la page « n'est plus disponible » et dans la liste de gestion de l'équipe.
class Communication::BlogReadingTest < ApplicationSystemTestCase
  TITLE = "Anticonstitutionnellement : le mot le plus long du français".freeze
  # Une adresse collée dans un titre : un seul « mot » de 50 caractères, plus large qu'une carte de 360 px.
  URL_TITLE = "Inscriptions sur lnclass.com/eleves/inscription-rentree-2026".freeze
  PHONES = [ [ 390, 844 ], [ 360, 780 ] ].freeze

  setup do
    @author = create_team_member(team_role: "content", first_name: "Awa", last_name: "Koné")
    @article = create_article(author: @author, title: TITLE, cover: create_article_image, cover_alt: "Une salle de classe")
    @url_article = create_article(author: @author, title: URL_TITLE, published_at: 1.day.ago)
  end

  # La page ne défile pas sur le côté, et l'élément ne déborde pas de sa propre boîte.
  def assert_no_horizontal_scroll(selector)
    width = page.evaluate_script("document.documentElement.clientWidth")
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, width, "#{current_path} défile sur le côté"
    element = find(selector)
    assert_operator page.evaluate_script("arguments[0].scrollWidth", element), :<=,
                    page.evaluate_script("arguments[0].clientWidth", element), "#{selector} déborde de sa boîte"
  end

  test "a title with a word wider than the screen wraps on the article, the list, the 410 page and the team list" do
    PHONES.each do |size|
      with_mobile_viewport(size) do
        visit blog_article_path(@article.slug)
        assert_selector "h1#article_title", text: TITLE
        assert_no_horizontal_scroll "h1#article_title"

        visit blog_article_path(@url_article.slug)
        assert_no_horizontal_scroll "h1#article_title"

        visit blog_path
        assert_no_horizontal_scroll "#blog_article_#{@article.slug} h2"
        assert_no_horizontal_scroll "#blog_article_#{@url_article.slug} h2"
      end
    end

    @article.update_columns(status: "archived", archived_at: Time.current)
    PHONES.each do |size|
      with_mobile_viewport(size) do
        visit blog_article_path(@article.slug)
        assert_no_horizontal_scroll "#article_gone h1"
      end
    end

    sign_in_as @author
    PHONES.each do |size|
      with_mobile_viewport(size) do
        visit teams_articles_path
        assert_selector "tr#article_#{@article.public_id}", text: TITLE
        assert_no_horizontal_scroll "main"
        assert_no_horizontal_scroll "tr#article_#{@url_article.public_id} td:first-child"
      end
    end
  end
end
