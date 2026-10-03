# 🧠 DOMAINE · Entities::Identity::DeletionRequest
# Rôle : demande de suppression d'un compte élève, enregistrée à sa réception ; à traiter dans les 30 jours (rappel lu)
# ADR  : 0036 (amendement 2 du 2026-10-02)
module Entities
  module Identity
    DeletionRequest = Data.define(:id, :user_id, :requested_on, :status) do
      def self.due_on(requested_on) = requested_on + DeletionRequest::DELAY_DAYS

      # → :late (échéance dépassée) | :soon (5 jours ou moins) | :on_time. Lu à l'affichage, jamais stocké, sans job.
      def self.stage(requested_on:, today:)
        left = (due_on(requested_on) - today).to_i
        return :late if left.negative?

        left <= DeletionRequest::WARNING_DAYS ? :soon : :on_time
      end

      def pending? = status == DeletionRequest::PENDING
      def due_on = DeletionRequest.due_on(requested_on)
      def stage(today) = DeletionRequest.stage(requested_on:, today:)
    end

    DeletionRequest::PENDING = "pending".freeze
    DeletionRequest::PROCESSED = "processed".freeze
    DeletionRequest::CANCELLED = "cancelled".freeze
    # Échéance = réception + 30 jours ; ambre quand il en reste 5 ou moins (à partir du 25e jour), en retard au-delà.
    DeletionRequest::DELAY_DAYS = 30
    DeletionRequest::WARNING_DAYS = 5
  end
end
