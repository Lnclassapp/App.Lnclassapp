# 🧠 DOMAINE · Entities::Communication::PushMotive
# Rôle : les sept motifs de notification, leur priorité, leur famille (événement à toute heure, rappel en journée) ; chacun a sa case
# ADR  : 0146 (§3.2) · 0147 (§4, §6, amendement du 2026-11-27 II) · PRD §3.1
module Entities
  module Communication
    module PushMotive
      # Du plus urgent au moins urgent : un seul motif part par passage (PRD §3.2).
      PRIORITY = %w[quiz_prep assignment_due assignment_new announcement unfinished result inactive].freeze
      ALL = PRIORITY
      # Ce qui arrive à l'élève : part dès l'événement, à toute heure.
      EVENTS = %w[assignment_new announcement result].freeze
      # Ce qu'on lui rappelle : part entre 6 h et 21 h à Abidjan (ReminderHours).
      REMINDERS = (PRIORITY - EVENTS).freeze
      # Chaque motif a sa case dans l'administration (porteur, 2026-11-27) : cochée, il part ; décochée, rien ne part.
      AUTOMATABLE = PRIORITY
      # Les validations du jour écrites avant le 2026-11-27, que l'historique relit : tout sauf l'annonce.
      PLANNABLE = (PRIORITY - %w[announcement]).freeze

      # 0 pour le plus urgent ; un motif inconnu lève, il ne passe pas en silence.
      def self.rank(motive) = PRIORITY.index(motive) || raise(ArgumentError, "motif inconnu : #{motive.inspect}")
      def self.valid?(motive) = PRIORITY.include?(motive)
      def self.automatable?(motive) = AUTOMATABLE.include?(motive)
      def self.event?(motive) = EVENTS.include?(motive)
    end
  end
end
