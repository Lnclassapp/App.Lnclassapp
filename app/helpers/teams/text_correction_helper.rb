# 🌐 UI · Teams::TextCorrectionHelper — un champ des modales « Corriger le texte » (notion, exercice), sans objet ActiveModel
# Rôle : libellé, champ (texte ou zone), erreur sous le champ reliée par aria-describedby, aux classes de ui_field ; l'erreur vient d'un code du use case
# ADR  : 0113 (§4.6, amendement du 2026-11-14) · UDR : 0005, 0042 (amendement du 2026-11-14) · chantier edition-texte-lecon
module Teams
  module TextCorrectionHelper
    # errors : { Symbol => [Symbol] } du use case ; key : la clé de ce champ dans errors ; scope : la clé I18n des messages.
    def text_correction_field(name:, id:, label:, value:, errors:, key:, as: :textarea, maxlength: nil, rows: 3, scope: "teams.text_errors")
      code = Array(errors[key]).first
      error_id = "#{id}_error"
      classes = class_names(ComponentsHelper::FIELD_INPUT, as == :textarea ? "py-3" : "min-h-tap",
                            ComponentsHelper::FIELD_STATES[code ? :invalid : :valid])
      control = if as == :textarea
                  text_area_tag(name, value, id:, rows:, maxlength:, class: classes, "aria-invalid": ("true" if code), "aria-describedby": (error_id if code))
      else
                  text_field_tag(name, value, id:, maxlength:, class: classes, autocomplete: "off", "aria-invalid": ("true" if code),
                                              "aria-describedby": (error_id if code))
      end
      tag.div(class: "space-y-1.5") do
        safe_join([
          label_tag(id, label, class: "block text-sm font-medium text-ink"), control,
          (tag.p(id: error_id, class: "text-sm font-medium text-error") { t("#{scope}.#{code}", default: t("#{scope}.invalid")) } if code)
        ].compact)
      end
    end
  end
end
