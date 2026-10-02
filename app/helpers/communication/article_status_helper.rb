# 🌐 UI · Communication::ArticleStatusHelper — état d'un article du blog et entrées de son menu ⋮
# Rôle : badge d'état (liste de gestion, modale, bandeau d'aperçu) ; Modifier, Aperçu, puis la transition permise par l'état
# ADR  : 0035, 0073 · UDR : 0042, 0064, 0065
module Communication
  module ArticleStatusHelper
    # Les mêmes tons que le catalogue : un état a une seule apparence dans toute l'application.
    ARTICLE_STATUS_TONES = { "draft" => :warning, "published" => :success, "archived" => :neutral }.freeze
    # [état de départ, état d'arrivée] → [clé de teams.articles.menu, icône, action de la route].
    ARTICLE_TRANSITIONS = {
      %w[draft published] => %w[publish check-circle publish],
      %w[published archived] => %w[archive archive-box archive],
      %w[archived published] => %w[republish arrow-uturn-up publish]
    }.freeze

    def article_status_badge(status)
      tone = ARTICLE_STATUS_TONES.fetch(status)
      ui_badge(t("teams.articles.status.#{status}"), tone:, dot: true)
    end

    # article : tout objet qui répond à public_id, slug et status (ligne de la liste de gestion). Conteneur sans boîte,
    # remplacé avec la ligne par les streams de transition.
    def article_menu_items(article:)
      items = [
        ui_dropdown_item(t("teams.articles.menu.edit"), href: edit_teams_article_path(article.public_id), icon: "pencil-square",
                                                        frame: "modal"),
        ui_dropdown_item(t("teams.articles.menu.#{article.status == 'published' ? 'view' : 'preview'}"),
                         href: blog_article_path(article.slug), icon: "eye"),
        *Entities::Communication::Article::TRANSITIONS.fetch(article.status).map do |target|
          key, icon, action = ARTICLE_TRANSITIONS.fetch([ article.status, target ])
          ui_dropdown_item t("teams.articles.menu.#{key}"), href: public_send(:"#{action}_teams_article_path", article.public_id),
                                                            method: :patch, icon:
        end
      ]
      tag.div(safe_join(items), id: "article_transitions_#{article.public_id}", class: "contents", role: "none")
    end
  end
end
