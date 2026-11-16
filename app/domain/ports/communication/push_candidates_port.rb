# 🧠 DOMAINE · Ports::Communication::PushCandidatesPort
# Rôle : les motifs prêts à l'instant now, tous élèves confondus (lus au moment de l'envoi, jamais émis par un use case)
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.2)
module Ports
  module Communication
    module PushCandidatesPort
      # → [Entities::Communication::PushCandidate]
      # user_ids : limite aux élèves donnés (relecture d'un seul élève juste avant l'envoi) ; nil = tous.
      def for(now:, user_ids: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #for"
      end
    end
  end
end
