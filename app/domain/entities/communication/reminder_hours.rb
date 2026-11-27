# 🧠 DOMAINE · Entities::Communication::ReminderHours
# Rôle : les heures où un rappel peut partir : de 6 h à 21 h, heure d'Abidjan, tous les jours ; un événement part à toute heure
# ADR  : 0147 (amendement du 2026-11-27 II) · remplace les fenêtres d'envoi de l'ADR-0146 §3.2
module Entities
  module Communication
    # Abidjan est à UTC+0 toute l'année, sans heure d'été : l'heure UTC est l'heure d'Abidjan. [6 h, 21 h).
    module ReminderHours
      HOURS = 6...21

      def self.open?(time) = HOURS.cover?(time.utc.hour)
    end
  end
end
