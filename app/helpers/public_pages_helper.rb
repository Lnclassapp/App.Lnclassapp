# 🌐 UI · PublicPagesHelper — liens vers les pages publiques en ligne (mission, données, CGU, CGV)
# Rôle : une seule liste, lue par le pied de page de la homepage, /aide et la carte d'aide ; « Blog » dès un article publié
# UDR  : 0063 (§3.1, §3.4), 0064 (§3.5)
module PublicPagesHelper
  # → [[libellé, chemin], …] des pages demandées qui sont en ligne, dans l'ordre de PagesController::PAGES.
  def public_page_links(pages = Communication::PagesController::PAGES)
    unknown = pages - Communication::PagesController::PAGES
    raise ArgumentError, "public_page_links : page inconnue (#{unknown.join(', ')})" if unknown.any?

    Communication::PagesController::PAGES
      .select { pages.include?(it) && Communication::PagesController.online?(it) }
      .map { [ t("public_pages.links.#{it}"), public_send(:"#{it}_path") ] }
  end

  # → [libellé, chemin] du blog s'il a au moins un article publié, sinon nil (UDR-0064 §3.5). Une requête par rendu.
  # Lu par le pied de page de la homepage et par celui de la carte d'aide, jamais par /aide.
  def blog_link
    return @blog_link if defined?(@blog_link)

    @blog_link = ([ t("public_pages.links.blog"), blog_path ] if Queries::Communication::PublishedArticlesQuery.new.any?)
  end
end
