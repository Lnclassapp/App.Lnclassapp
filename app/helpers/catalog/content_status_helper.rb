# 🌐 UI · Catalog::ContentStatusHelper — statut d'un cours, d'une fiche ou d'un exercice, et ses transitions
# Rôle : badge du statut pour tous ; pour l'équipe, le badge (panneau) et les transitions en entrées du menu ⋮, que les streams remplacent
# ADR  : 0035 · UDR : 0005, 0007, 0042
module Catalog
  module ContentStatusHelper
    CONTENT_STATUS_TONES = { "draft" => :warning, "published" => :success, "archived" => :neutral }.freeze
    # Type de chaque contenu et attribut qui l'adresse dans les routes de l'équipe.
    CONTENT_TYPES = {
      "Entities::Catalog::Course" => [ "course", :slug ],
      "Entities::Catalog::Essential" => [ "essential", :slug ],
      "Entities::Assessment::Exercise" => [ "exercise", :public_id ]
    }.freeze
    TRANSITION_ACTIONS = { "published" => "publish", "archived" => "archive" }.freeze
    TRANSITION_ICONS = { "publish" => "check-circle", "archive" => "archive-box" }.freeze

    def content_status_badge(status)
      tone = CONTENT_STATUS_TONES.fetch(status)
      ui_badge(t("catalog.content_status.#{status}"), tone:, dot: true)
    end

    # Rendu pour l'équipe seulement : le badge du statut, seul visible dans l'en-tête ; les streams le remplacent.
    def content_status_panel(record:)
      type, key = content_address(record)
      tag.div(id: "content_status_#{type}_#{key}", class: "flex flex-wrap items-center gap-2") do
        content_status_badge(record.status)
      end
    end

    # Entrées du menu ⋮ de l'équipe : une par transition de ContentStatus::TRANSITIONS (PATCH publish, archive), dans un
    # conteneur sans boîte que les streams remplacent avec le panneau.
    def content_transition_items(record:)
      type, key = content_address(record)
      items = Entities::Catalog::ContentStatus::TRANSITIONS.fetch(record.status).map do |target|
        action = TRANSITION_ACTIONS.fetch(target)
        ui_dropdown_item t("catalog.content_status.actions.#{action}"), href: public_send("#{action}_teams_#{type}_path", key),
                                                                        method: :patch, icon: TRANSITION_ICONS.fetch(action)
      end
      tag.div(safe_join(items), id: "content_transitions_#{type}_#{key}", class: "contents", role: "none")
    end

    private

    def content_address(record)
      type, key_attribute = CONTENT_TYPES.fetch(record.class.name)
      [ type, record.public_send(key_attribute) ]
    end
  end
end
