# 🌐 UI · PageTitleHelper — titre de l'onglet « Page · Espace · Lnclass »
# Rôle : `page_title` nomme la page et renvoie le titre complet ; `document_title` le compose pour le layout
# UDR  : 0054 (§3.1)
module PageTitleHelper
  SEPARATOR = " · ".freeze
  PRODUCT = "Lnclass".freeze

  # Le premier appel d'un rendu nomme la page ; les suivants (une modale rendue dans la page) composent seulement
  # leur titre, sans prendre celui de la page. → titre complet, échappé une fois.
  def page_title(page)
    raise ArgumentError, "page_title : titre vide" if page.blank?

    content_for(:page_title, page) unless content_for?(:page_title)
    compose_title(page)
  end

  def document_title
    compose_title(content_for(:page_title))
  end

  private

  # L'espace est celui du rôle connecté ; un visiteur, ou un compte dont le second facteur est en cours, n'en a pas.
  def compose_title(page)
    space = t("shared.page_title.spaces.#{current_actor.role}") if current_actor
    safe_join([ page, space, PRODUCT ].compact_blank, SEPARATOR)
  end
end
