# 🧠 DOMAINE · Entities::Catalog::AutomaticLoadStage
# Rôle : reconnaît, par le nom de l'environnement Railway, où le chargement automatique des leçons tourne (Develop, Staging) ou se tait, et quel remplacement il fait
# ADR  : chargement-automatique-des-lecons-hors-production, 0123
module Entities
  module Catalog
    # kind : :load (Develop, Staging), :skip (production, environnement de PR, nom absent) ou :unknown (tout autre nom, gardé dans name).
    # whole_lessons : Develop seul (ADR-0123) remplace entières les leçons v3 du programme.
    AutomaticLoadStage = Data.define(:kind, :name, :whole_lessons) do
      def initialize(whole_lessons: false, **) = super

      # Le nom, casse et espaces ignorés. Demo ne charge pas les leçons du dépôt (il a le jeu standard). Un environnement de PR ne charge rien : il a déjà ses leçons (ADR-0108).
      def self.for(name:, pr_environment:)
        clean = name.to_s.strip
        return new(kind: :skip, name: nil) if pr_environment || clean.empty? || AutomaticLoadStage::SILENT.include?(clean.downcase)
        return new(kind: :load, name: nil, whole_lessons: clean.downcase == AutomaticLoadStage::WHOLE_LESSONS) if AutomaticLoadStage::LOADING.include?(clean.downcase)

        new(kind: :unknown, name: clean)
      end

      def load? = kind == :load
      def skip? = kind == :skip
      def unknown? = kind == :unknown
      def whole_lessons? = load? && whole_lessons

      # Le remplacement d'une leçon du dépôt : :exercises (elle porte des sujets de devoir, ADR-0122, partout où l'on charge), :lesson
      # (Develop, dossier du programme v3, ADR-0123 : remplacée entière) ou nil (pas chargée ici).
      def mode_for(level_directory:, subjects:)
        return :exercises if subjects
        return :lesson if whole_lessons? && V3ProgrammeLevels.include?(level_directory)

        nil
      end
    end
    AutomaticLoadStage::LOADING = %w[develop staging].freeze
    AutomaticLoadStage::SILENT = %w[production demo].freeze
    AutomaticLoadStage::WHOLE_LESSONS = "develop"
  end
end
