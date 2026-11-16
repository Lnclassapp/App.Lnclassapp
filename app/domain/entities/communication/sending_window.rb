# 🧠 DOMAINE · Entities::Communication::SendingWindow
# Rôle : les fenêtres d'envoi à l'heure d'Abidjan : lundi-samedi 12 h-14 h et 17 h-20 h, dimanche 9 h-20 h
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
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

        (0..1).each do |offset|
          day = local.beginning_of_day + offset.days
          hours_of(day).each do |range|
            opening = day + range.begin.hours
            return opening if opening > local
          end
        end
        raise "aucune fenêtre trouvée" # inatteignable : chaque jour a au moins une ouverture
      end

      def self.hours_of(day) = day.sunday? ? SUNDAY : WEEKDAY
      private_class_method :hours_of
    end
  end
end
