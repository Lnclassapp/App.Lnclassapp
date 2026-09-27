# 🌐 UI · Catalog::ContentStatusHelper — statut d'un cours, d'une fiche ou d'un exercice, et ses transitions
# Rôle : badge du statut pour tous ; panneau de l'équipe avec un bouton par transition permise, que les streams remplacent
# ADR  : 0035 · UDR : 0005, 0007
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

    def content_status_badge(status)
      tone = CONTENT_STATUS_TONES.fetch(status)
      ui_badge(t("catalog.content_status.#{status}"), tone:, dot: true)
    end

    # Rendu pour l'équipe seulement : le badge et les transitions de ContentStatus::TRANSITIONS (PATCH publish, archive).
    def content_status_panel(record:)
      type, key_attribute = CONTENT_TYPES.fetch(record.class.name)
      key = record.public_send(key_attribute)
      tag.div(id: "content_status_#{type}_#{key}", class: "flex flex-wrap items-center gap-2") do
        safe_join([ content_status_badge(record.status), *content_transition_buttons(type, key, record.status) ])
      end
    end

    private

    def content_transition_buttons(type, key, status)
      Entities::Catalog::ContentStatus::TRANSITIONS.fetch(status).map do |target|
        action = TRANSITION_ACTIONS.fetch(target)
        button_to(t("catalog.content_status.actions.#{action}"), public_send("#{action}_teams_#{type}_path", key),
                  method: :patch, form_class: "contents",
                  class: class_names(ComponentsHelper::BUTTON_BASE, ComponentsHelper::BUTTON_VARIANTS[:secondary],
                                     ComponentsHelper::BUTTON_SIZES[:sm]))
      end
    end
  end
end
