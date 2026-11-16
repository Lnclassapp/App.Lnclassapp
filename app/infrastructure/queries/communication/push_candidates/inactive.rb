# 🔌 INFRA · Queries::Communication::PushCandidates::Inactive
# Rôle : candidats du motif inactive (élève sans activité depuis 3, 7 ou 14 jours) ; vide au Lot 0, remplie par le Lot B
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Inactive
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
