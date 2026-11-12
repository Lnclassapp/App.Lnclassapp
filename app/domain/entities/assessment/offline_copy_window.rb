# 🧠 DOMAINE · Entities::Assessment::OfflineCopyWindow
# Rôle : les bornes de l'heure d'origine d'une copie rendue hors ligne : [émission du paquet, réception], 30 jours au plus avant la réception
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5, menace R4)
module Entities
  module Assessment
    module OfflineCopyWindow
      # Secondes : la copie d'un téléphone n'est jamais plus vieille que la durée de la session (SessionLifetime).
      MAX_AGE = 30 * 24 * 3600

      # → [plancher, plafond] (Time). Le plafond est la réception ; le plancher, le plus récent de l'émission du paquet et de
      # réception - 30 jours, sans jamais passer au-dessus du plafond.
      def self.bounds(issued_at:, received_at:)
        floor = [ issued_at, received_at - MAX_AGE ].max
        [ [ floor, received_at ].min, received_at ]
      end

      # L'heure de l'appareil ramenée dans les bornes ; sans heure, la réception.
      def self.clamp(time:, issued_at:, received_at:)
        floor, ceiling = bounds(issued_at:, received_at:)
        return ceiling if time.nil?

        time.clamp(floor, ceiling)
      end
    end
  end
end
