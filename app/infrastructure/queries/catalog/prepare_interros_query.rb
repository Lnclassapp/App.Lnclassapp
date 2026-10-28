# 🔌 INFRA · Queries::Catalog::PrepareInterrosQuery
# Rôle : les exercices de la leçon pour « Prépare interros », groupés par notion puis « Toute la leçon », avec l'état de l'élève ; squelette du Lot 0
# ADR  : XXXX-exercice-de-lecon-avec-sujet-et-notion-sans-page · UDR : XXXX-page-de-la-lecon-fiche-de-revision-et-prepare-interros §3.4
module Queries
  module Catalog
    class PrepareInterrosQuery
      # groups : [{ essential_slug:, title:, exercises: [ExerciseRow] }] dans l'ordre des notions ; lesson_wide : [ExerciseRow] par position ;
      # targets : les classes où l'enseignant peut assigner (vide hors enseignant). Contrat gelé par le Lot 0 : le Lot B le remplit.
      Prepare = Data.define(:groups, :lesson_wide, :targets)

      EMPTY = Prepare.new(groups: [], lesson_wide: [], targets: [])

      # → Prepare. Squelette : des listes vides (le Lot B le complète).
      def call(course_slug:, actor:) = EMPTY
    end
  end
end
