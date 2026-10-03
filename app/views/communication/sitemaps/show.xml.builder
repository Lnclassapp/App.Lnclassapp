# 🌐 UI · communication/sitemaps/show.xml — plan du site (protocole sitemaps.org 0.9)
# Rôle : adresses absolues sur l'hôte canonique (canonical_url, jamais request.host) ; lastmod = updated_at d'un article
# ADR  : 0074 (§4.6) · PRD blog : BL-19
xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  [ root_path, help_path, *public_page_links.map(&:last), blog_path ].each do |path|
    xml.url { xml.loc canonical_url(path) }
  end

  @articles.each do |article|
    xml.url do
      xml.loc canonical_url(blog_article_path(article.slug))
      xml.lastmod article.updated_at.utc.iso8601
    end
  end
end
