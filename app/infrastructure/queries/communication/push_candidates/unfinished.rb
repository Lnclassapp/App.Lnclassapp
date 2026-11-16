# 🔌 INFRA · Queries::Communication::PushCandidates::Unfinished
# Rôle : candidats du motif unfinished (session d'exercice ouverte depuis plus de 24 h) ; vide au Lot 0, remplie par le Lot D
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Unfinished
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
