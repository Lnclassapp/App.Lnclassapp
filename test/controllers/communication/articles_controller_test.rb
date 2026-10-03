require "test_helper"

# UDR-0064 §3.2 à §3.4, §3.6 et §3.8 : le rendu du blog public. La liste paginée par dix et son état vide, la page d'un
# article (un seul h1, signature, date, couverture, texte et ses images), les balises de tête de l'aperçu partagé sur
# l'hôte canonique, et les budgets de la lecture (HTML, aucun script, aucun tiers). Les statuts (404, 410), le compteur
# et la lecture connectée sont dans test/integration/communication/articles_test.rb.
class Communication::ArticlesControllerTest < ActionDispatch::IntegrationTest
  CANONICAL = "https://lnclass.com".freeze
  HEAD_TAGS = "head meta[name=description], head link[rel=canonical], head meta[property], head meta[name=robots]".freeze

  setup { @author = create_team_member(team_role: "content", second_factor: false, first_name: "Aya", last_name: "Bamba") }

  def publish(title: "Article #{factory_sequence}", at: 1.day.ago, **attributes)
    create_article(author: @author, title:, published_at: at, **attributes)
  end

  # Les balises de tête, dans l'ordre du document : [nom ou propriété, contenu ou adresse].
  def head_tags
    css_select(HEAD_TAGS).map do |tag|
      tag.name == "link" ? [ "canonical", tag["href"] ] : [ tag["name"] || tag["property"], tag["content"] ]
    end
  end

  def assert_default_share_image(tags)
    image = tags.assoc("og:image")&.last
    assert_match %r{\A#{CANONICAL}/assets/blog/partage(-\w+)?\.png\z}, image
    assert_equal [ [ "og:image:width", "1200" ], [ "og:image:height", "630" ], [ "og:image:alt", "Logo de Lnclass" ] ],
                 tags.select { it.first.start_with?("og:image:") }
  end

  # Le texte enregistré par l'adaptateur, comme le formulaire de l'équipe l'enregistre : assaini à l'écriture.
  def write_published(body:, title: "Écrit par l'équipe")
    repository = Repositories::Communication::ArticleRepository.new
    dto = Dtos::Communication::ArticleInput.new(title:, excerpt: "Un résumé.", body:)
    article = repository.create(dto:, author_id: @author.id, at: Time.current).value
    repository.transition(id: article.id, to: "published", at: Time.current)
    Orm::Article.find(article.id)
  end

  # ---------- Liste /blog ----------

  test "BL-06: with no published article, /blog shows the empty state, without list nor pagination" do
    create_article(author: @author, status: "draft")
    create_article(author: @author, status: "archived")

    get blog_path

    assert_response :success
    assert_select "title", "Blog · Lnclass"
    assert_select "main.bg-paper > div.max-w-prose" do
      assert_select "h1#blog_title", "Blog"
      assert_select "#blog_empty", text: /Aucun article pour le moment/
      assert_select "#blog_empty", text: /Revenez bientôt : les premiers articles arrivent\./
      assert_select "#blog_empty a[href='#{root_path}']", "Découvrir Lnclass"
    end
    assert_select "ol#blog_articles", 0
    assert_select "a[rel=next], a[rel=prev]", 0
  end

  test "the list has the logo, the « Accueil » back link and a single h1, without the connected shell" do
    publish

    get blog_path

    assert_select "h1", count: 1
    assert_select "main#main", 0
    assert_select "a[aria-label='Lnclass, accueil'][href='#{root_path}'] img[alt='']"
    assert_select "a[href='#{root_path}']", text: /Accueil/
  end

  test "BL-01: a card shows the title as its only link, the excerpt, the date and the cover, nothing else" do
    cover = create_article_image
    article = publish(title: "Réviser le BEPC en 4 semaines", excerpt: "Un plan simple, semaine après semaine.",
                      at: Time.zone.local(2026, 10, 5, 9), cover:, signature: "author")

    get blog_path

    assert_select "ol#blog_articles[aria-labelledby=blog_title][data-turbo-prefetch=false] > li", 1
    assert_select "li #blog_article_#{article.slug}.relative" do
      assert_select "a", count: 1
      assert_select "h2 a[href='#{blog_article_path(article.slug)}']", "Réviser le BEPC en 4 semaines"
      assert_select "p", text: "Un plan simple, semaine après semaine."
      assert_select "time[datetime='2026-10-05']", "Publié le 5 octobre 2026"
      assert_select "img[src='#{blog_image_path(cover.public_id)}'][alt=''][width='64'][height='48'][loading=eager]"
    end
    assert_no_match "Aya Bamba", response.body
    assert_no_match "lecture", response.body
  end

  test "BL-01: most recent first, ten cards a page; eleven articles make two pages linked by rel=next and rel=prev" do
    articles = Array.new(11) { publish(title: "Article #{it + 1}", at: Time.zone.local(2026, 9, it + 1, 9), cover: create_article_image) }

    get blog_path

    assert_select "ol#blog_articles > li", 10
    assert_equal articles.drop(1).reverse.map(&:title), css_select("ol#blog_articles h2 a").map { it.text.strip }
    assert_select "ol#blog_articles img[loading=eager]", 1
    assert_select "ol#blog_articles li:first-child img[loading=eager]"
    assert_select "ol#blog_articles img[loading=lazy]", 9
    assert_select "a[rel=next][href='#{blog_path(page: 2)}']"
    assert_select "a[rel=prev]", 0

    get blog_path(page: 2)

    assert_select "title", "Blog, page 2 · Lnclass"
    assert_select "ol#blog_articles > li", 1
    assert_select "ol#blog_articles h2 a", "Article 1"
    assert_select "ol#blog_articles img[loading=eager]", 1
    assert_select "a[rel=prev][href='#{blog_path(page: 1)}']"
    assert_select "a[rel=next]", 0
  end

  test "an absent, explicit or invalid page number reads the first page; a page beyond the last is not found" do
    publish(title: "Le seul article")

    [ blog_path, blog_path(page: 1), blog_path(page: "abc"), blog_path(page: 0), blog_path(page: -2),
      "#{blog_path}?page[]=2" ].each do |path|
      get path

      assert_response :success, path
      assert_select "ol#blog_articles h2 a", "Le seul article"
      assert_select "link[rel=canonical][href='#{CANONICAL}/blog']"
    end

    get blog_path(page: 2)

    assert_response :not_found
    assert_select "h1", 0
    assert_no_match "Le seul article", response.body
  end

  test "BL-03: the list carries its share tags, on the canonical host, with the default image" do
    publish

    get blog_path

    tags = head_tags
    assert_equal [
      [ "description", "Conseils de révision, préparation du BEPC et du BAC, nouveautés : les articles de l'équipe Lnclass." ],
      [ "canonical", "#{CANONICAL}/blog" ],
      [ "og:site_name", "Lnclass" ], [ "og:locale", "fr_FR" ], [ "og:type", "website" ],
      [ "og:title", "Le blog de Lnclass" ],
      [ "og:description", "Conseils de révision, préparation du BEPC et du BAC, nouveautés : les articles de l'équipe Lnclass." ],
      [ "og:url", "#{CANONICAL}/blog" ]
    ], tags.first(8)
    assert_default_share_image(tags)
    assert_equal 12, tags.size
    assert_nil tags.assoc("article:published_time")
  end

  test "BL-03: the second page is canonical at its own address" do
    11.times { publish }

    get blog_path(page: 2)

    assert_equal [ [ "canonical", "#{CANONICAL}/blog?page=2" ] ], head_tags.select { it.first == "canonical" }
    assert_equal "#{CANONICAL}/blog?page=2", head_tags.assoc("og:url").last
  end

  test "BL-03: the canonical host follows config.x.canonical_host, never the host of the request" do
    publish
    Rails.configuration.x.canonical_host = "www.lnclass.com"

    get blog_path

    assert_equal "https://www.lnclass.com/blog", head_tags.assoc("canonical").last
    assert_match %r{\Ahttps://www\.lnclass\.com/assets/blog/partage}, head_tags.assoc("og:image").last
  ensure
    Rails.configuration.x.canonical_host = "lnclass.com"
  end

  # ---------- Page d'un article ----------

  test "BL-02: the page of an article answers 200 without the shell: logo, « Blog », one h1, signature, date, body, next steps" do
    article = publish(title: "Réviser le BEPC en 4 semaines", at: Time.zone.local(2026, 10, 5, 9),
                      body: "<div>Commencez par les mathématiques.</div>")

    get blog_article_path(article.slug)

    assert_response :success
    assert_select "title", "Réviser le BEPC en 4 semaines · Lnclass"
    assert_select "main#main", 0
    assert_select "main.bg-paper > div.max-w-prose" do
      assert_select "a[aria-label='Lnclass, accueil'][href='#{root_path}']"
      assert_select "a[href='#{blog_path}']", text: /Blog/
      assert_select "article[aria-labelledby=article_title]" do
        assert_select "h1#article_title", "Réviser le BEPC en 4 semaines"
        assert_select "p#article_byline", text: /L'équipe Lnclass/
        assert_select "p#article_byline span[aria-hidden=true]", "·"
        assert_select "p#article_byline time[datetime='2026-10-05']", "Publié le 5 octobre 2026"
        assert_select "#article_body .trix-content", text: /Commencez par les mathématiques\./
      end
      assert_select "nav#article_next[aria-label='Suite de la lecture']" do
        assert_select "a[href='#{root_path}']", "Découvrir Lnclass"
        assert_select "a[href='#{blog_path}']", "Tous les articles"
      end
    end
    assert_select "h1", count: 1
    assert_select "#article_status_banner", 0
    assert_select "figure.mb-8", 0
    assert_no_match "Le résumé de l'article.", css_select("main").text
  end

  test "BL-02: a title typed with the editor's « Titre » button stays an h2: the page keeps a single h1" do
    article = write_published(body: "<h1>Semaine 1</h1><div>Les fractions.</div>")

    get blog_article_path(article.slug)

    assert_select "h1", count: 1
    assert_select "h1#article_title", "Écrit par l'équipe"
    assert_select "#article_body h2", "Semaine 1"
  end

  test "the « Blog » back link brings the reader back to the page of the list they came from" do
    article = publish

    get blog_article_path(article.slug), headers: { "Referer" => "http://www.example.com/blog?page=3" }

    assert_select "a[href='/blog?page=3']", text: /Blog/
  end

  test "BL-18: the byline names the author of an article signed by them, « L'équipe Lnclass » once anonymized" do
    article = publish(signature: "author")

    get blog_article_path(article.slug)

    assert_select "p#article_byline", text: /Aya Bamba/

    @author.update_columns(anonymized_at: Time.current)
    get blog_article_path(article.slug)

    assert_select "p#article_byline", text: /L'équipe Lnclass/
    assert_no_match "Aya Bamba", response.body
  end

  test "BL-18: an article signed « L'équipe Lnclass » never shows its author's name" do
    get blog_article_path(publish(signature: "team").slug)

    assert_select "p#article_byline", text: /L'équipe Lnclass/
    assert_no_match "Bamba", response.body
  end

  test "BL-03: the page of an article carries the twelve share tags, its cover in absolute address on lnclass.com" do
    cover = create_article_image
    article = publish(title: "Réviser le BEPC", excerpt: "Un plan simple.", at: Time.zone.local(2026, 10, 5, 9), cover:,
                      cover_alt: "Une élève qui révise")

    get blog_article_path(article.slug)

    url = "#{CANONICAL}/blog/#{article.slug}"
    assert_equal [
      [ "description", "Un plan simple." ], [ "canonical", url ], [ "og:site_name", "Lnclass" ], [ "og:locale", "fr_FR" ],
      [ "og:type", "article" ], [ "og:title", "Réviser le BEPC" ], [ "og:description", "Un plan simple." ], [ "og:url", url ],
      [ "og:image", "#{CANONICAL}/blog/images/#{cover.public_id}" ], [ "og:image:width", "64" ], [ "og:image:height", "48" ],
      [ "og:image:alt", "Une élève qui révise" ], [ "article:published_time", "2026-10-05" ]
    ], head_tags
    assert_select "head meta[name=robots]", 0
  end

  test "BL-03: without a cover, the share image is the default image of Lnclass" do
    article = publish

    get blog_article_path(article.slug)

    tags = head_tags
    assert_default_share_image(tags)
    assert_equal "article", tags.assoc("og:type").last
  end

  test "BL-14: the cover and every image of the body are served by Lnclass, with their size and alt, the body's lazily" do
    cover = create_article_image
    images = [ create_article_image(alt: "Un cahier ouvert"), create_article_image(alt: "Un tableau noir") ]
    article = publish(cover:, cover_alt: "Une élève qui révise", body: article_body_with(*images))

    get blog_article_path(article.slug)

    assert_select "article figure.mb-8 img[src='#{blog_image_path(cover.public_id)}'][alt='Une élève qui révise']" \
                  "[width='64'][height='48'][loading=eager][fetchpriority=high][decoding=async]"
    images.each do |image|
      assert_select "#article_body figure img[src='#{blog_image_path(image.public_id)}'][alt='#{image.alt}']" \
                    "[width='64'][height='48'][loading=lazy][decoding=async]"
    end
    css_select("img").each do |img|
      assert_match %r{\A/(blog/images|assets)/}, img["src"], "image hors de lnclass.com"
      assert img.key?("alt"), "image sans alt : #{img['src']}"
    end
    assert_select "article img:not([width]), article img:not([height])", 0
  end

  test "a caption written in the editor stays visible under its image" do
    image = create_article_image(alt: "Un cahier ouvert")
    body = %(<action-text-attachment sgid="#{image.attachable_sgid}" content-type="image/jpeg" width="64" height="48" ) +
           %(caption="Le cahier de Mariam"></action-text-attachment>)
    article = publish(body:)

    get blog_article_path(article.slug)

    assert_select "#article_body figure figcaption", "Le cahier de Mariam"
  end

  test "BL-16: neither a script, an onerror attribute nor a javascript: link reaches the page" do
    payload = %(<div>Bonjour<script>alert(1)</script><img src="x" onerror="alert(2)"></div>) +
              %(<div><a href="javascript:alert(3)">piège</a></div>)

    [ write_published(body: payload), publish(body: payload) ].each do |article|
      get blog_article_path(article.slug)

      body = css_select("#article_body").to_s
      assert_no_match(/<script|onerror|javascript:/i, body)
      assert_match "Bonjour", body
    end
  end

  test "BL-21: an article of 1 500 words and five images weighs less than 150 KB, adds no script and no controller" do
    images = Array.new(5) { create_article_image(alt: "Image #{it + 1}") }
    words = Array.new(1_500) { "révision" }
    paragraphs = words.each_slice(100).map { "<div>#{it.join(' ')}.</div>" }.join
    article = publish(cover: create_article_image, body: paragraphs + article_body_with(*images, text: "Fin."))

    get blog_article_path(article.slug)

    assert_operator response.body.bytesize, :<, 150 * 1024
    assert_select "#article_body img[loading=lazy]", 5
    assert_equal [ "application" ], css_select("script").map { File.basename(it["src"].to_s).split(/[-.]/).first }
    assert_select "main [data-controller]", 0
    assert_select "main [data-action]", 0
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "data-controller=\"math\"", response.body
  end

  test "BL-21: a list page of ten cards weighs less than 150 KB and adds no script" do
    10.times { publish(excerpt: "é" * 200, cover: create_article_image) }

    get blog_path

    assert_operator response.body.bytesize, :<, 150 * 1024
    assert_equal 1, css_select("script").size
    assert_select "main [data-controller]", 0
  end
end
