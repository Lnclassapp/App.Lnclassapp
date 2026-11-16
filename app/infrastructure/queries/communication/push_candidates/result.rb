# 🔌 INFRA · Queries::Communication::PushCandidates::Result
# Rôle : candidats du motif result (copie hors ligne corrigée ou médaille sans visite) ; vide au Lot 0, remplie par le Lot D
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Result
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
