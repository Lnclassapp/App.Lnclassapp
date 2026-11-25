# 🔌 INFRA · Queries::Communication::PushCandidates::QuizPrep
# Rôle : candidats du motif quiz_prep : feuille « interro » (1 ou 2 exercices) de la classe principale de l'élève, à rendre demain, pas encore rendue ; même lecture que assignment_due
# ADR  : 0146 (§3.2) · 0121 (§4) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class QuizPrep < AssignmentDue
        private

        def kind = :interros
        def motive = "quiz_prep"
        def variables(material, count) = { material:, count: }
      end
    end
  end
end
