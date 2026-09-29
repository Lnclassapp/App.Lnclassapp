# 🌐 UI · Teams::ImportsHelper — message d'une erreur du rapport d'import
# Rôle : une erreur de schéma se lit comme une phrase selon son mot-clé json_schemer, jamais comme le mot-clé brut
# ADR  : 0039, 0066 · UDR : 0053
module Teams
  module ImportsHelper
    # Le mot-clé reste dans les données du rapport ; seul son affichage est traduit, avec une phrase générique par défaut.
    def import_error_message(error)
      params = error.params.to_h.symbolize_keys
      return t("teams.imports.error_codes.#{error.code}", **params) unless error.code == "schema"

      generic = t("teams.imports.error_codes.schema")
      keyword = params[:keyword].presence
      keyword ? t("teams.imports.schema_keywords.#{keyword}", default: generic) : generic
    end
  end
end
