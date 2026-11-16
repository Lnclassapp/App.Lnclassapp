# 🔌 INFRA · Queries::Communication::PushCandidates::Announcement
# Rôle : candidats du motif announcement (annonce de l'équipe publiée depuis moins de 48 h) ; vide au Lot 0, remplie par le Lot E
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class Announcement
        # → [Entities::Communication::PushCandidate]
        def for(now:) = []
      end
    end
  end
end
