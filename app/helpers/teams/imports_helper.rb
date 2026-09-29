# 🌐 UI · Teams::ImportsHelper — message d'une erreur du rapport d'import
# Rôle : une erreur de schéma se lit comme une phrase selon son mot-clé json_schemer, jamais comme le mot-clé brut
# ADR  : 0039, 0066 · UDR : 0053
module Teams
  module ImportsHelper
    # Le mot-clé reste dans les données du rapport ; seul son affichage est traduit, avec une phrase générique par défaut.
    def import_error_message(error)
      params = error.params.to_h.symbolize_keys
      return format_mismatch_message(params) if error.code == "format_mismatch"
      return t("teams.imports.error_codes.#{error.code}", **params) unless error.code == "schema"

      generic = t("teams.imports.error_codes.schema")
      keyword = params[:keyword].presence
      keyword ? t("teams.imports.schema_keywords.#{keyword}", default: generic) : generic
    end

    private

    # Un fichier d'un autre type d'import nomme ce type, pour que l'équipe sache quel bouton utiliser ; sinon, le message générique.
    def format_mismatch_message(params)
      received, expected = [ params[:received], params[:expected] ].map { |format| import_kind_of(format) }
      return t("teams.imports.error_codes.format_mismatch", expected: params[:expected]) unless received && expected

      t("teams.imports.error_codes.format_of_other_kind", received: params[:received], received_kind: t("import_kinds.#{received}"),
                                                           expected: params[:expected], expected_kind: t("import_kinds.#{expected}"))
    end

    def import_kind_of(format) = Entities::Catalog::ImportKind::ALL.values.find { it.format == format }&.kind
  end
end
