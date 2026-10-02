# 🌐 UI · Communication::ArticlesHelper — adresses et dates du blog public
# Rôle : adresse d'une image d'article, adresse absolue sur l'hôte canonique (jamais request.host), date d'un article
# ADR  : 0073 · UDR : 0064
module Communication
  module ArticlesHelper
    # image : tout objet qui répond à public_id (Image de la query, ligne d'article_images). Seul chemin d'une image,
    # couverture comprise, servi par Lnclass (BL-14).
    def article_image_src(image) = blog_image_path(image.public_id)

    # Lien canonique, og:url, og:image, plan du site, robots.txt (ADR-0073 §4.6).
    def canonical_url(path) = "https://#{Rails.configuration.x.canonical_host}#{path}"

    # « 5 octobre 2026 » : aucune vue ne formate une date d'article elle-même.
    def article_date(date) = l(date, format: :article_published)
  end
end
