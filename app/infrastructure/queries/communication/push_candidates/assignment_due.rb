# 🔌 INFRA · Queries::Communication::PushCandidates::AssignmentDue
# Rôle : candidats du motif assignment_due (feuille « Prépare devoirs » (3 exercices ou plus) à rendre demain) ; vide au Lot 0, remplie par le Lot C
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class AssignmentDue
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
