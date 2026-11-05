# 🔌 INFRA · Queries::Assessment::ClassExerciseSuccessQuery
# Rôle : la réussite de la classe sur chaque exercice d'une feuille (meilleure copie par élève, seuil de réussite actuel)
# ADR  : lecture-de-la-classe-par-la-direction · UDR : suivi-de-la-classe-sur-une-lecon §3.2
module Queries
  module Assessment
    class ClassExerciseSuccessQuery
      # Contrat gelé (suivi-classe-lecon, Lot 0), corps écrit au Lot B : exercise_ids = les public_id des exercices de la feuille.
      # → { exercise public_id => Entities::Assessment::ClassSuccess } ; {} tant que le Lot B n'est pas livré.
      def call(classroom_public_id:, exercise_ids:)
        {}
      end
    end
  end
end
