# 🧠 DOMAINE · Entities::Catalog::ImportKind
# Rôle : registre fermé des cinq types d'import : format, version, racines, cible, plafond et policy
# ADR  : 0028, 0039, 0055
module Entities
  module Catalog
    module ImportKind
      VERSION = 1
      MAX_BYTES = 20 * 1024 * 1024
      MAX_ERRORS = 1_000
      BATCH_SIZE = 100

      # roots_key : clé des éléments racines dans l'enveloppe ; target_key : clé de la cible (slug), ou nil
      Definition = Data.define(:kind, :format, :version, :roots_key, :target_key, :target_required, :max_roots, :policy) do
        def authorize(actor:) = policy.new.call(actor:)
      end

      ALL = [
        Definition.new(kind: "schools", format: "lnclass.schools", version: VERSION, roots_key: "schools",
                       target_key: "drena", target_required: false, max_roots: 5_000,
                       policy: Policies::School::ManageSchoolPolicy),
        Definition.new(kind: "course_tree", format: "lnclass.course-tree", version: VERSION, roots_key: "courses",
                       target_key: nil, target_required: false, max_roots: 500,
                       policy: Policies::Catalog::ManageContentPolicy),
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

      def self.valid?(kind) = ALL.key?(kind.to_s)

      def self.fetch(kind)
        ALL.fetch(kind.to_s) { raise ArgumentError, "type d'import inconnu : #{kind.inspect}" }
      end
    end
  end
end
