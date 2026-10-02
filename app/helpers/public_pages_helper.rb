# 🌐 UI · PublicPagesHelper — liens vers les pages publiques en ligne (mission, données, CGU, CGV)
# Rôle : une seule liste, lue par le pied de page de la homepage, /aide et la carte d'aide ; une page hors ligne n'a aucun lien
# UDR  : 0063 (§3.1, §3.4)
module PublicPagesHelper
  # → [[libellé, chemin], …] des pages demandées qui sont en ligne, dans l'ordre de PagesController::PAGES.
  def public_page_links(pages = Communication::PagesController::PAGES)
    unknown = pages - Communication::PagesController::PAGES
    raise ArgumentError, "public_page_links : page inconnue (#{unknown.join(', ')})" if unknown.any?

    Communication::PagesController::PAGES
      .select { pages.include?(it) && Communication::PagesController.online?(it) }
      .map { [ t("public_pages.links.#{it}"), public_send(:"#{it}_path") ] }
  end
end
