# 🧠 DOMAINE · Entities::Catalog::ImportError
# Rôle : une erreur d'import localisée par son chemin JSON, avec un motif d'une liste fermée
# ADR  : 0039, 0063, 0066, 0068
module Entities
  module Catalog
    # path : notation JSON (« schools[412].type », « $ » pour le fichier) ; params : valeurs pour le message ;
    # file : nom d'affichage du fichier dans un envoi de plusieurs fichiers, nil sinon (ADR-0068).
    ImportError = Data.define(:path, :code, :params, :file) do
      def initialize(path:, code:, params: {}, file: nil)
        raise ArgumentError, "motif d'import inconnu : #{code.inspect}" unless ImportError::CODES.include?(code.to_s)

        super(path:, code: code.to_s, params:, file:)
      end

      # Le fichier n'est écrit que s'il est connu : un rapport d'un seul fichier garde la forme d'avant.
      def to_h = super.compact

      # Une erreur bloquante rejette tout le fichier, sans aucune écriture.
      def blocking? = ImportError::BLOCKING.include?(code)
    end
    ImportError::BLOCKING = %w[json_invalid format_mismatch version_unsupported unknown_target too_many_roots
                               too_large].freeze
    ImportError::ELEMENT = %w[schema blank too_long unknown_level unknown_series unknown_material unknown_drena
                              series_not_allowed invalid_value question_structure write_failed national_code_taken taken no_latin_character
                              duplicate_in_files].freeze
    ImportError::CODES = (ImportError::BLOCKING + ImportError::ELEMENT).freeze
  end
end
