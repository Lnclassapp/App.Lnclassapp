require "test_helper"

# ADR-0074 §4.2, §4.7, §4.8 et §7 : le parcours HTTP du blog public. Un brouillon est introuvable (404) pour qui ne gère
# pas le blog, un archivé répond 410 sans jamais renvoyer vers la connexion, un article remis en ligne garde son
# adresse et sa date ; la lecture est comptée pour un visiteur et un élève, jamais pour l'équipe, un robot, un
# préchargement ni un aperçu ; une personne connectée lit le blog sans être renvoyée vers son accueil.
class Communication::ArticlesTest < ActionDispatch::IntegrationTest
  PHONE = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Mobile Safari/537.36".freeze

  setup { @author = create_team_member(team_role: "content", second_factor: false) }

  def read(article, headers: {}) = get(blog_article_path(article.slug), headers: { "User-Agent" => PHONE }.merge(headers))
  def reads(article) = article.reload.reads_count

  def outsiders
    school = create_school
    { "un élève" => create_student(classroom: create_classroom), "un enseignant" => create_teacher(school:),
      "une direction" => create_school_admin(school:), "un membre du Terrain" => create_team_member(team_role: "field") }
  end

  def assert_not_found_without(article)
    assert_response :not_found
    assert_select "h1", 0
    assert_no_match article.title, response.body
    assert_no_match "Le texte secret du brouillon", response.body
  end

  test "BL-04: a draft is not found by a visitor, a student, a teacher, a direction or a Field member" do
    draft = create_article(author: @author, status: "draft", title: "Brouillon confidentiel",
                           body: "<div>Le texte secret du brouillon.</div>")

    read(draft)
    assert_not_found_without(draft)

    outsiders.each do |who, user|
      sign_in_as user
      read(draft)

      assert_not_found_without(draft)
      assert_equal 0, reads(draft), who
    end
  end

  test "an unknown address is not found" do
    get blog_article_path("adresse-inconnue")

    assert_response :not_found
  end

  test "BL-05: an archived article answers 410 « Cet article n'est plus disponible », with a link to /blog and noindex" do
    archived = create_article(author: @author, status: "archived", title: "Un article retiré", body: "<div>Ancien texte.</div>")

    read(archived)

    assert_response :gone
    assert_select "title", "Article indisponible · Lnclass"
    assert_select "head meta[name=robots][content='noindex, nofollow']"
    assert_select "head meta[property], head link[rel=canonical], head meta[name=description]", 0
    assert_select "section#article_gone" do
      assert_select "h1", "Cet article n'est plus disponible"
      assert_select "p", "Il a été retiré du blog de Lnclass."
      assert_select "a[href='#{blog_path}']", "Tous les articles"
    end
    assert_select "h1", count: 1
    assert_select "a[aria-label='Lnclass, accueil'][href='#{root_path}']"
    assert_no_match "Un article retiré", response.body
    assert_no_match "Ancien texte", response.body
  end

  test "BL-05: a signed-in student also gets the 410, never a redirect to the sign-in page" do
    archived = create_article(author: @author, status: "archived")
    sign_in_as create_student(classroom: create_classroom)

    read(archived)

    assert_response :gone
    assert_select "#article_gone h1", "Cet article n'est plus disponible"
  end

  test "BL-05: an archived article leaves the list" do
    create_article(author: @author, status: "archived", title: "Retiré du blog")
    create_article(author: @author, title: "Toujours en ligne")

    get blog_path

    assert_select "ol#blog_articles h2 a", "Toujours en ligne"
    assert_no_match "Retiré du blog", response.body
  end

  test "BL-11: put back online, an article answers 200 again at the same address, dated of its first publication" do
    repository = Repositories::Communication::ArticleRepository.new
    article = create_article(author: @author, title: "Réviser le BEPC", published_at: Time.zone.local(2026, 10, 5, 9))
    repository.transition(id: article.id, to: "archived", at: Time.zone.local(2026, 10, 20))
    read(article)
    assert_response :gone

    repository.transition(id: article.id, to: "published", at: Time.zone.local(2026, 11, 2))
    read(article)

    assert_response :success
    assert_select "h1#article_title", "Réviser le BEPC"
    assert_select "#article_byline time[datetime='2026-10-05']", "Publié le 5 octobre 2026"
  end

  test "the team previews a draft with the « Brouillon » banner and noindex, without share tags" do
    draft = create_article(author: @author, status: "draft", title: "En préparation", excerpt: nil)
    sign_in_as create_team_member(team_role: "content")

    read(draft)

    assert_response :success
    assert_select "p#article_status_banner" do
      assert_select "span", text: "Brouillon"
      assert_match "Visible par l'équipe seulement.", css_select("p#article_status_banner").text
    end
    assert_select "head meta[name=robots][content='noindex, nofollow']"
    assert_select "head meta[property], head link[rel=canonical], head meta[name=description]", 0
    assert_select "h1#article_title", "En préparation"
    assert_select "#article_byline time", 0
    assert_equal 0, reads(draft)
  end

  test "an administrator previews an archived article with the « Archivé » banner" do
    archived = create_article(author: @author, status: "archived", title: "Retiré")
    sign_in_as create_team_member(team_role: "admin")

    read(archived)

    assert_response :success
    assert_select "p#article_status_banner", text: /Archivé/
    assert_select "p#article_status_banner", text: /Retiré du blog : les visiteurs ne le voient plus\./
    assert_select "head meta[name=robots][content='noindex, nofollow']"
  end

  test "BL-17: a visitor, a student, a team member, then a robot read the article: the counter is at 2" do
    article = create_article(author: @author)

    read(article)
    assert_equal 1, reads(article)

    sign_in_as create_student(classroom: create_classroom)
    read(article)
    assert_equal 2, reads(article)

    sign_out
    sign_in_as create_team_member(team_role: "field")
    read(article)
    assert_response :success
    sign_out

    read(article, headers: { "User-Agent" => "WhatsApp/2.23.20.0 A" })
    read(article, headers: { "User-Agent" => "curl/8.5.0" })
    assert_response :success
    assert_equal 2, reads(article)
  end

  test "PRD §3: the same person who reads the article again is counted twice, visitor or signed in (no deduplication)" do
    article = create_article(author: @author)

    2.times { read(article) }
    assert_equal 2, reads(article)

    sign_in_as create_student(classroom: create_classroom)
    2.times { read(article) }
    assert_equal 4, reads(article)
  end

  test "BL-17: neither a prefetch, a preview (X-Purpose: preview), a HEAD request nor another format counts" do
    article = create_article(author: @author)

    %w[Sec-Purpose X-Sec-Purpose Purpose].each { read(article, headers: { it => "prefetch" }) }
    read(article, headers: { "X-Purpose" => "preview" })
    head blog_article_path(article.slug), headers: { "User-Agent" => PHONE }
    get blog_article_path(article.slug, format: :json), headers: { "User-Agent" => PHONE }

    assert_equal 0, reads(article)
  end

  test "BL-17: the preview of a draft changes no counter" do
    draft = create_article(author: @author, status: "draft")
    published = create_article(author: @author)
    sign_in_as create_team_member(team_role: "content")

    read(draft)
    read(published)

    assert_equal [ 0, 0 ], [ reads(draft), reads(published) ]
  end

  test "BL-17: the counter never touches updated_at" do
    article = create_article(author: @author)
    updated_at = article.updated_at

    read(article)

    assert_equal [ 1, updated_at ], article.reload.then { [ it.reads_count, it.updated_at ] }
  end

  test "a failure of the counter never blocks the page" do
    article = create_article(author: @author)
    repository = Repositories::Communication::ArticleRepository
    repository.alias_method :original_increment_reads, :increment_reads
    repository.define_method(:increment_reads) { |article_id:| raise ActiveRecord::ConnectionTimeoutError, "pool épuisé" }

    report = assert_error_reported(ActiveRecord::ConnectionTimeoutError) { read(article) }

    assert_response :success
    assert_select "h1#article_title", article.title
    assert report.handled
    assert_equal article.id, report.context[:article_id]
  ensure
    repository.alias_method :increment_reads, :original_increment_reads
    repository.remove_method :original_increment_reads
  end

  test "an error of the counter that is not a database failure is not hidden: the page fails, Rails reports it" do
    article = create_article(author: @author)
    repository = Repositories::Communication::ArticleRepository
    repository.alias_method :original_increment_reads, :increment_reads
    repository.define_method(:increment_reads) { |article_id:| raise ArgumentError, "bogue" }

    assert_raises(ArgumentError) { read(article) }
  ensure
    repository.alias_method :increment_reads, :original_increment_reads
    repository.remove_method :original_increment_reads
  end

  test "BL-20: a signed-in student reads /blog and an article without being sent to their home" do
    article = create_article(author: @author, title: "Pour les élèves")
    sign_in_as create_student(classroom: create_classroom)

    get blog_path

    assert_response :success
    assert_select "ol#blog_articles h2 a", "Pour les élèves"
    assert_select "main#main", 0

    read(article)

    assert_response :success
    assert_select "h1#article_title", "Pour les élèves"
    assert_select "main#main", 0
  end

  test "a teacher, a direction and the Field team read the list too, without redirect" do
    create_article(author: @author)

    outsiders.except("un élève").each do |who, user|
      sign_in_as user
      get blog_path

      assert_response :success, who
    end
  end
end
