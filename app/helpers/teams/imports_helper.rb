# 🌐 UI · Teams::ImportsHelper — message d'une erreur du rapport d'import, nom d'un import de plusieurs fichiers
# Rôle : une erreur de schéma se lit comme une phrase selon son mot-clé json_schemer, jamais comme le mot-clé brut
# ADR  : 0039, 0066, 0068 · UDR : 0053, 0055
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

    # « limites.json », « limites.json et 9 autres fichiers », ou le libellé d'un rapport sans fichier (UDR-0055 §3.4).
    def import_files_label(import)
      return t("teams.imports.import_row.no_file") if import.filename.nil?
      return import.filename if import.file_count <= 1

      t("teams.imports.files_label", first: import.filename, count: import.file_count - 1)
    end

    # Libellés du résumé de la sélection, lus par le contrôleur teams--import-files : aucun texte en dur dans le JavaScript.
    def import_files_summary_texts
      %w[one other kilobytes megabytes too_many_files not_json file_too_large total_too_large].to_h do |key|
        [ "#{key.camelize(:lower)}Text", t("teams.imports.new.files_summary.#{key}") ]
      end
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
