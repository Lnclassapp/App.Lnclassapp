# 🧠 DOMAINE · Entities::Catalog::AutomaticLoadStage
# Rôle : reconnaît, par le nom de l'environnement Railway, où le chargement automatique des leçons tourne (Develop, Staging) ou se tait, et quel remplacement il fait
# ADR  : chargement-automatique-des-lecons-hors-production, 0123, standard-de-test
module Entities
  module Catalog
    # kind : :load (Develop, Staging), :skip (production, environnement de PR, nom absent) ou :unknown (tout autre nom, gardé dans name).
    # whole_lessons : Develop seul remplace entière chaque leçon v3 du dépôt, de tout dossier de niveau, 3ème et leçons à sujets comprises
    # (ADR-0123 §4.2 et standard-de-test, amendements du 2026-11-04 ; rien n'est supprimé ailleurs). create_missing : Staging seul crée les
    # leçons v3 absentes du programme et ne touche pas aux présentes.
    AutomaticLoadStage = Data.define(:kind, :name, :whole_lessons, :create_missing) do
      def initialize(whole_lessons: false, create_missing: false, **) = super

      # Le nom, casse et espaces ignorés. Demo ne charge pas les leçons du dépôt (il a le jeu standard). Un environnement de PR ne charge rien : il a déjà ses leçons (ADR-0108).
      def self.for(name:, pr_environment:)
        clean = name.to_s.strip
        return new(kind: :skip, name: nil) if pr_environment || clean.empty? || AutomaticLoadStage::SILENT.include?(clean.downcase)
        if AutomaticLoadStage::LOADING.include?(clean.downcase)
          return new(kind: :load, name: nil, whole_lessons: clean.downcase == AutomaticLoadStage::WHOLE_LESSONS,
                     create_missing: clean.downcase == AutomaticLoadStage::CREATE_MISSING)
        end

        new(kind: :unknown, name: clean)
      end

      def load? = kind == :load
      def skip? = kind == :skip
      def unknown? = kind == :unknown
      def whole_lessons? = load? && whole_lessons
      def create_missing? = load? && create_missing

      # Le remplacement d'une leçon du dépôt : :lesson (Develop, tout fichier v3 : remplacée entière, cours, notions, fiches, exercices et
      # sujets, quels que soient son dossier et ses sujets), :exercises (ailleurs, elle porte des sujets de devoir, ADR-0122), :create_only
      # (Staging, dossier du programme v3 : créée si absente, intacte sinon) ou nil (pas chargée ici, ou environnement sans chargement).
      def mode_for(level_directory:, subjects:)
        return unless load?
        return :lesson if whole_lessons?
        return :exercises if subjects
        return unless V3ProgrammeLevels.include?(level_directory)

        # Seul Staging arrive ici : Develop est sorti plus haut (:lesson), et seuls Develop et Staging chargent.
        :create_only
      end
    end
    AutomaticLoadStage::LOADING = %w[develop staging].freeze
    AutomaticLoadStage::SILENT = %w[production demo].freeze
    AutomaticLoadStage::WHOLE_LESSONS = "develop"
    AutomaticLoadStage::CREATE_MISSING = "staging"
  end
end
