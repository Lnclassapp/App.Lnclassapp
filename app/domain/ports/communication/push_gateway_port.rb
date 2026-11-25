# 🧠 DOMAINE · Ports::Communication::PushGatewayPort
# Rôle : envoie une notification déjà rédigée à un abonnement ; ne connaît ni l'élève ni le motif
# ADR  : 0146 (§4.2)
module Ports
  module Communication
    module PushGatewayPort
      # subscription : Entities::Communication::PushSubscription ; message : Entities::Communication::PushMessage.
      # → :delivered | :gone (abonnement à supprimer) | :retry | :not_configured. Ne lève pas.
      def deliver(subscription:, message:)
        raise NotImplementedError, "#{self.class} doit implémenter #deliver"
      end
    end
  end
end
