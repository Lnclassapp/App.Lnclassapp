# 🔌 INFRA · Queries::Communication::PushCandidates::QuizPrep
# Rôle : candidats du motif quiz_prep (feuille « Prépare interros » (1 ou 2 exercices) à rendre demain) ; vide au Lot 0, remplie par le Lot C
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class QuizPrep
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
