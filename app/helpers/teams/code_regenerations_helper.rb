# 🌐 UI · Teams::CodeRegenerationsHelper — droit aux gestes de masse, sélection lisible d'une régénération
# Rôle : menu « Codes » et entrée de la fiche réservés à l'équipe admin ; rappel des filtres dans la modale, sélection du rapport
# ADR  : 0096 · UDR : 0104, 0105 · jamais un code ni un jeton
module Teams
  module CodeRegenerationsHelper
    # RegenerateCodesInBulkPolicy : content et field n'ont ni le menu ni l'entrée (UDR-0104).
    def can_regenerate_codes_in_bulk?
      Policies::School::RegenerateCodesInBulkPolicy.new.call(actor: current_actor).success?
    end

    # Filtres autres que la DRENA et l'établissement, dans l'ordre de la liste : « Lycée · Actif · « moderne » ». Une valeur
    # hors de sa liste fermée est ignorée, comme par la liste (Orm::School.list_filtered). → [String]
    def code_regeneration_filter_labels(selection)
      school = Entities::School::School
      [ (t("school_types.#{selection.school_type}") if school::SCHOOL_TYPES.include?(selection.school_type)),
        (t("teams.schools.cycles.#{selection.cycle}") if school::CYCLES.include?(selection.cycle)),
        (t("school_statuses.#{selection.status}") if school::STATUSES.include?(selection.status)),
        (t("teams.code_regenerations.form.search", search: selection.search) if selection.search) ].compact
    end

    # Sous-titre du rapport (UDR-0105) : « Sélection : DRENA Abidjan 1 · Lycée · année 2026-2027 ». scope : les noms lus
    # par Queries::School::CodeRegenerationPreviewQuery#scope. → String
    def code_regeneration_selection_label(import, scope)
      raw = import.details["selection"] || {}
      selection = Dtos::School::SchoolSelection.from(raw)
      keys = "teams.imports.show.selection"
      parts = selection.school ? [ scope.school_name || t("#{keys}.unknown_school") ] : selection_parts(selection, scope, keys)
      if import.kind == Entities::Catalog::ImportKind::CLASSROOM_LINK_REGENERATION
        year = raw["school_year"]
        parts << (year ? t("#{keys}.school_year", year:) : t("#{keys}.all_years"))
      end
      t("#{keys}.label", parts: parts.join(" · "))
    end

    private

    def selection_parts(selection, scope, keys)
      drena = (scope.drena_name ? t("#{keys}.drena", name: scope.drena_name) : t("#{keys}.unknown_drena") if selection.drena)
      [ drena, *code_regeneration_filter_labels(selection) ].compact.presence || [ t("#{keys}.all") ]
    end
  end
end
