# 🧠 DOMAINE · Entities::Catalog::ImportKind
# Rôle : registre fermé des cinq types d'import (format, racines, cible, plafonds, policy) et des types de rapport
# ADR  : 0028, 0039, 0056, 0066, 0068
module Entities
  module Catalog
    module ImportKind
      VERSION = 1
      # Par fichier. Un envoi de plusieurs fichiers a aussi son plafond total (max_total_bytes).
      MAX_BYTES = 20 * 1024 * 1024
      MAX_ERRORS = 1_000
      BATCH_SIZE = 100

      # roots_key : clé des éléments racines dans l'enveloppe ; target_key : clé de la cible (slug), ou nil.
      # max_roots vaut pour tout l'envoi ; max_files et max_total_bytes bornent l'envoi (ADR-0068).
      Definition = Data.define(:kind, :format, :version, :roots_key, :target_key, :target_required, :max_roots, :policy,
                               :max_files, :max_total_bytes) do
        # Plusieurs fichiers partagent un seul contexte de validation : un type à cible n'en accepte qu'un.
        def initialize(target_key:, max_files: 1, max_total_bytes: MAX_BYTES, **)
          raise ArgumentError, "un type d'import à cible n'accepte qu'un fichier" if max_files > 1 && !target_key.nil?

          super
        end

        def authorize(actor:) = policy.new.call(actor:)
        def multiple_files? = max_files > 1
      end

      ALL = [
        Definition.new(kind: "schools", format: "lnclass.schools", version: VERSION, roots_key: "schools",
                       target_key: "drena", target_required: false, max_roots: 5_000,
                       policy: Policies::School::ManageSchoolPolicy),
        Definition.new(kind: "course_tree", format: "lnclass.course-tree", version: VERSION, roots_key: "courses",
                       target_key: nil, target_required: false, max_roots: 500,
                       policy: Policies::Catalog::ManageContentPolicy, max_files: 50, max_total_bytes: 50 * 1024 * 1024),
        Definition.new(kind: "essentials", format: "lnclass.essentials", version: VERSION, roots_key: "essentials",
                       target_key: "course", target_required: true, max_roots: 2_000,
                       policy: Policies::Catalog::ManageContentPolicy),
        Definition.new(kind: "exercises", format: "lnclass.exercises", version: VERSION, roots_key: "exercises",
                       target_key: "essential", target_required: true, max_roots: 10_000,
                       policy: Policies::Catalog::ManageContentPolicy),
        Definition.new(kind: "drenas", format: "lnclass.drenas", version: VERSION, roots_key: "drenas",
                       target_key: nil, target_required: false, max_roots: 500,
                       policy: Policies::School::ManageSchoolPolicy)
      ].index_by(&:kind).freeze
      KINDS = ALL.keys.freeze

      # Rapport sans fichier suivi par le même écran : la génération des classes manquantes (ADR-0056). Pas un type
      # d'import : ni format, ni téléversement.
      CLASSROOM_GENERATION = "classrooms"
      REPORT_POLICIES = ALL.transform_values(&:policy).merge(CLASSROOM_GENERATION => Policies::School::ManageSchoolPolicy).freeze
      REPORT_KINDS = REPORT_POLICIES.keys.freeze

      def self.valid?(kind) = ALL.key?(kind.to_s)

      # Lire un rapport de ce type. Un type inconnu lève KeyError.
      def self.authorize_report(kind:, actor:) = REPORT_POLICIES.fetch(kind.to_s).new.call(actor:)

      def self.fetch(kind)
        ALL.fetch(kind.to_s) { raise ArgumentError, "type d'import inconnu : #{kind.inspect}" }
      end
    end
  end
end
