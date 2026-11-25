# 🧠 DOMAINE · Entities::Communication::SendingWindow
# Rôle : les fenêtres d'envoi à l'heure d'Abidjan : lundi-samedi 12 h-14 h et 17 h-20 h, dimanche 9 h-20 h
# ADR  : 0146 (§3.2) · PRD §3.1
module Entities
  module Communication
    # Abidjan est à UTC+0 toute l'année, sans heure d'été : l'heure UTC est l'heure d'Abidjan. Les fenêtres sont [début, fin) en heures.
    module SendingWindow
      WEEKDAY = [ 12...14, 17...20 ].freeze
      SUNDAY = [ 9...20 ].freeze

      def self.open?(time)
        local = time.utc
        hours_of(local).any? { it.cover?(local.hour) }
      end

      # → Time : time si la fenêtre est ouverte, sinon l'ouverture suivante (même jour ou jours d'après).
      def self.next_open_at(time)
        local = time.utc
        return local if open?(local)

        # Chaque jour a au moins une ouverture : celle du lendemain suit toujours `time`, `find` ne renvoie jamais nil.
        (0..1).flat_map { |offset| openings_of(local.beginning_of_day + offset.days) }.find { it > local }
      end

      def self.openings_of(day) = hours_of(day).map { day + it.begin.hours }
      private_class_method :openings_of

      def self.hours_of(day) = day.sunday? ? SUNDAY : WEEKDAY
      private_class_method :hours_of
    end
  end
end
