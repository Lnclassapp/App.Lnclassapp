# 🧠 DOMAINE · Ports::Communication::PushDataEraserPort
# Rôle : contrat de l'effacement des données push d'un élève dont le compte est supprimé sur demande
# ADR  : XXXX-notifications-web-push-aux-eleves (§4.3), 0036 (amendement)
module Ports
  module Communication
    module PushDataEraserPort
      # Efface ses abonnements, sa préférence et ses envois (aucune ligne d'un autre compte). Appelé dans la transaction de l'anonymisation. → true
      def erase_for(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #erase_for"
      end
    end
  end
end
