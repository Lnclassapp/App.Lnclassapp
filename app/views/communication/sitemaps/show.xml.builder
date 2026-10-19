# 🌐 UI · communication/sitemaps/show.xml — plan du site (protocole sitemaps.org 0.9)
# Rôle : adresses absolues sur l'hôte canonique (canonical_url, jamais request.host) ; lastmod = updated_at d'un article ou du cours le plus récent
# ADR  : 0074 (§4.6), 0099 (§4.4 : catalogue public, jamais d'adresse à paramètre) · PRD blog : BL-19 · PRD catalogue : CC-21
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

  # ADR-0099 §4.4 : /niveaux, puis les niveaux, les couples niveau × série et les matières qui ont un cours publié.
  if @catalog.levels.any?
    catalog = [ [ public_levels_path, @catalog.levels.map(&:last).max ] ]
    catalog += @catalog.levels.map { |slug, lastmod| [ public_level_path(slug), lastmod ] }
    catalog += @catalog.series.map { |level, series, lastmod| [ public_level_series_path(level, series), lastmod ] }
    catalog += @catalog.materials.map { |slug, lastmod| [ public_material_path(slug), lastmod ] }
    catalog.each do |path, lastmod|
      xml.url do
        xml.loc canonical_url(path)
        xml.lastmod lastmod.utc.iso8601
      end
    end
  end
end
