# 🧠 DOMAINE · Entities::Catalog::ContentStatus
# Rôle : cycle de vie commun des cours, fiches et exercices ; le retour au brouillon est interdit
# ADR  : 0035
module Entities
  module Catalog
    module ContentStatus
      VALUES = %w[draft published archived].freeze
      TRANSITIONS = { "draft" => %w[published], "published" => %w[archived], "archived" => %w[published] }.freeze

      # → success(to) | failure(:conflict, errors: { base: [:transition_not_allowed | :parent_not_published] })
      def self.transition(from:, to:, parent_published:)
        return ::Shared::Result.failure(:conflict, errors: { base: [ :transition_not_allowed ] }) unless TRANSITIONS.fetch(from, []).include?(to)
        return ::Shared::Result.failure(:conflict, errors: { base: [ :parent_not_published ] }) if to == "published" && !parent_published

        ::Shared::Result.success(to)
      end
    end
  end
end
