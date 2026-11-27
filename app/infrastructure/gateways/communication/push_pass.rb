# 🔌 INFRA · Gateways::Communication::PushPass
# Rôle : enfile un passage d'envoi (DeliverPushNotificationsJob) ; la file indisponible est signalée, jamais levée
# ADR  : 0147 (amendement du 2026-11-27 II) · adaptateur de Ports::Communication::PushPassPort
module Gateways
  module Communication
    class PushPass
      include Ports::Communication::PushPassPort

      # Enfilé après le commit de toutes les transactions ouvertes (tout de suite hors transaction) : le passage lit l'événement
      # enregistré ; une transaction annulée n'enfile rien.
      def request
        ActiveRecord.after_all_transactions_commit { enqueue }
        nil
      end

      private

      def enqueue
        ::Communication::DeliverPushNotificationsJob.perform_later
      rescue StandardError => error
        Rails.error.report(error, handled: true, context: { port: "PushPassPort" })
      end
    end
  end
end
