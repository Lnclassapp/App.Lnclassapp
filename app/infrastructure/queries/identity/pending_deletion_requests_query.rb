# 🔌 INFRA · Queries::Identity::PendingDeletionRequestsQuery
# Rôle : les demandes de suppression en attente, triées par échéance, et leur résumé pour la carte de l'accueil de l'équipe
# ADR  : 0036 (amendement 2 du 2026-10-02) · UDR : 0018, 0062
module Queries
  module Identity
    class PendingDeletionRequestsQuery
      PENDING = Entities::Identity::DeletionRequest::PENDING

      # Une ligne mène à la fiche du compte, retrouvée par son numéro (la recherche de l'équipe n'a pas d'autre clé).
      Row = Data.define(:public_id, :display_name, :contact, :requested_on) do
        def due_on = Entities::Identity::DeletionRequest.due_on(requested_on)
        def stage(today) = Entities::Identity::DeletionRequest.stage(requested_on:, today:)
      end

      # requested_on : la plus ancienne réception, donc la plus proche échéance.
      Summary = Data.define(:count, :requested_on) do
        def due_on = Entities::Identity::DeletionRequest.due_on(requested_on)
        def stage(today) = Entities::Identity::DeletionRequest.stage(requested_on:, today:)
      end

      # L'échéance est la réception + 30 jours : trier par réception, c'est trier par échéance.
      # → [Row], la plus proche échéance d'abord
      def call
        pending.joins(:user).order(:requested_on, :id)
               .pluck("users.public_id", "users.first_name", "users.last_name", "users.contact", :requested_on)
               .map { |public_id, first_name, last_name, contact, requested_on| Row.new(public_id:, display_name: "#{first_name} #{last_name}", contact:, requested_on:) }
      end

      # → Summary | nil (aucune demande en attente : aucune carte)
      def summary
        count, requested_on = pending.pick(Arel.sql("COUNT(*)"), Arel.sql("MIN(requested_on)"))
        Summary.new(count:, requested_on:) if count.positive?
      end

      private

      def pending = Orm::AccountDeletionRequest.where(status: PENDING)
    end
  end
end
