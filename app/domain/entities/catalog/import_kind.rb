# 🧠 DOMAINE · Entities::Catalog::ImportKind
# Rôle : registre fermé des trois types d'import (format, racines, cible, plafonds, policy) et des types de rapport
# ADR  : 0028, 0039, 0056, 0066, 0068, 0096, 0113, 0116
module Entities
  module Catalog
    module ImportKind
      VERSION = 1
      # Leçons complètes (ADR-0116 §4.1) : le format 3 porte la fiche de chaque notion et les figures ; les formats 1 et 2 sont
      # retirés (refus du fichier, raison format_retired).
      COURSE_TREE_VERSION = 3
      # Par fichier. Un envoi de plusieurs fichiers a aussi son plafond total (max_total_bytes).
      MAX_BYTES = 20 * 1024 * 1024
      MAX_ERRORS = 1_000
      BATCH_SIZE = 100

      # roots_key : clé des éléments racines dans l'enveloppe ; target_key : clé de la cible (slug), ou nil.
      # max_roots vaut pour tout l'envoi ; max_files et max_total_bytes bornent l'envoi (ADR-0068).
      # version : celle que l'on écrit et documente ; legacy_versions : les anciennes, encore lues (avec leur propre schéma).
      Definition = Data.define(:kind, :format, :version, :roots_key, :target_key, :target_required, :max_roots, :policy,
                               :max_files, :max_total_bytes, :legacy_versions) do
        # Plusieurs fichiers partagent un seul contexte de validation : un type à cible n'en accepte qu'un.
        def initialize(target_key:, max_files: 1, max_total_bytes: MAX_BYTES, legacy_versions: [], **)
          raise ArgumentError, "un type d'import à cible n'accepte qu'un fichier" if max_files > 1 && !target_key.nil?

          super
        end

        # Un entier seulement : 2.0 == 2 en Ruby, mais le schéma « v2.0 » n'existe pas.
        def accepts?(received) = received.is_a?(Integer) && (received == version || legacy_versions.include?(received))

        def authorize(actor:) = policy.new.call(actor:)
        def multiple_files? = max_files > 1
      end

      ALL = [
        Definition.new(kind: "schools", format: "lnclass.schools", version: VERSION, roots_key: "schools",
                       target_key: "drena", target_required: false, max_roots: 5_000,
                       policy: Policies::School::ManageSchoolPolicy),
        Definition.new(kind: "course_tree", format: "lnclass.course-tree", version: COURSE_TREE_VERSION, roots_key: "courses",
                       target_key: nil, target_required: false, max_roots: 500,
                       policy: Policies::Catalog::ManageContentPolicy, max_files: 50, max_total_bytes: 50 * 1024 * 1024),
        Definition.new(kind: "drenas", format: "lnclass.drenas", version: VERSION, roots_key: "drenas",
                       target_key: nil, target_required: false, max_roots: 500,
                       policy: Policies::School::ManageSchoolPolicy)
      ].index_by(&:kind).freeze
      KINDS = ALL.keys.freeze

      # Rapport sans fichier suivi par le même écran : la génération des classes manquantes (ADR-0056). Pas un type
      # d'import : ni format, ni téléversement.
      CLASSROOM_GENERATION = "classrooms"
      # Régénérations de masse (ADR-0096) : rapports sans fichier ni code ; toute l'équipe les lit, seul admin les lance.
      SCHOOL_CODE_REGENERATION = "school_codes"
      CLASSROOM_LINK_REGENERATION = "classroom_links"
      CODE_REGENERATIONS = [ SCHOOL_CODE_REGENERATION, CLASSROOM_LINK_REGENERATION ].freeze
      WITHOUT_FILE = [ CLASSROOM_GENERATION, *CODE_REGENERATIONS ].freeze
      # L'import d'exercices seuls est retiré (ADR-0113 §4.4) : il contournerait la règle des exercices. Ses rapports passés
      # restent lisibles par l'équipe de contenu, mais il n'est plus ni un type d'import ni un type de rapport proposé.
      RETIRED_REPORT_KINDS = %w[exercises].freeze
      REPORT_KINDS = (ALL.keys + WITHOUT_FILE).freeze
      REPORT_POLICIES = ALL.transform_values(&:policy).merge(WITHOUT_FILE.index_with { Policies::School::ManageSchoolPolicy },
                                                             RETIRED_REPORT_KINDS.index_with { Policies::Catalog::ManageContentPolicy }).freeze

      def self.valid?(kind) = ALL.key?(kind.to_s)

      # Lire un rapport de ce type. Un type inconnu lève KeyError.
      def self.authorize_report(kind:, actor:) = REPORT_POLICIES.fetch(kind.to_s).new.call(actor:)

      def self.fetch(kind)
        ALL.fetch(kind.to_s) { raise ArgumentError, "type d'import inconnu : #{kind.inspect}" }
      end
    end
  end
end
