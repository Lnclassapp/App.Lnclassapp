# 🧠 DOMAINE · Entities::Catalog::AutomaticLoadStage
# Rôle : reconnaît, par le nom de l'environnement Railway, où le chargement automatique des leçons tourne (Develop, Staging) ou se tait
# ADR  : chargement-automatique-des-lecons-hors-production
module Entities
  module Catalog
    # kind : :load (Develop, Staging), :skip (production, environnement de PR, nom absent) ou :unknown (tout autre nom, gardé dans name).
    AutomaticLoadStage = Data.define(:kind, :name) do
      # Le nom, casse et espaces ignorés. Un environnement de PR ne charge rien : il a déjà ses leçons (ADR-0108).
      def self.for(name:, pr_environment:)
        clean = name.to_s.strip
        return new(kind: :skip, name: nil) if pr_environment || clean.empty? || AutomaticLoadStage::SILENT.include?(clean.downcase)
        return new(kind: :load, name: nil) if AutomaticLoadStage::LOADING.include?(clean.downcase)

        new(kind: :unknown, name: clean)
      end

      def load? = kind == :load
      def skip? = kind == :skip
      def unknown? = kind == :unknown
    end
    AutomaticLoadStage::LOADING = %w[develop staging].freeze
    AutomaticLoadStage::SILENT = %w[production].freeze
  end
end
