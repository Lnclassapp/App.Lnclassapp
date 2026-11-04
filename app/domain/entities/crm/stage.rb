# 🧠 DOMAINE · Entities::Crm::Stage
# Rôle : étape affichée d'une école, calculée en croisant l'étape saisie et l'usage réel ; les deux faits d'usage ne se saisissent pas
# ADR  : XXXX (contexte crm)
module Entities
  module Crm
    module Stage
      ACTIVE_WINDOW = 14 # jours
      # Les quatre jugements de l'équipe, seuls saisissables ; « Inscrite » et « Active » sont des faits d'usage.
      TYPEABLE = %w[prospect demo_done subscribed lost].freeze
      DISPLAYED = %i[prospect demo_done registered active subscribed lost].freeze
      COMPUTED = %i[registered active].freeze

      # Priorité : Abonnée, Active, Perdue, Inscrite, Démo faite, Prospect. today est injecté (aucune horloge ici).
      def self.resolve(saved:, accounts_count:, last_activity_on:, today:)
        return :subscribed if saved == "subscribed"
        return :active if last_activity_on && last_activity_on > today - ACTIVE_WINDOW
        return :lost if saved == "lost"
        return :registered if accounts_count.positive?
        return :demo_done if saved == "demo_done"

        :prospect
      end

      def self.computed?(stage) = COMPUTED.include?(stage.to_sym)
    end
  end
end
