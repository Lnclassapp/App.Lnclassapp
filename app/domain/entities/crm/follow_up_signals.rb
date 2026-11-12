# 🧠 DOMAINE · Entities::Crm::FollowUpSignals
# Rôle : règle « À relancer », pure : les raisons pour lesquelles une école est à relancer (relance échue, perte d'usage, démo sans suite, inscrite sans démarrage)
# ADR  : XXXX (contexte crm) §4
module Entities
  module Crm
    module FollowUpSignals
      REASONS = %i[overdue usage_lost demo_stalled registered_idle].freeze
      USAGE_LOST_RANGE = (15..60) # jours depuis la dernière activité
      DEMO_SILENCE = 7 # jours sans échange
      IDLE_AFTER = 14 # jours depuis le premier rattachement

      # → [Symbol] dans l'ordre de REASONS ; vide pour une école désactivée ou affichée « Perdue ». today est injecté.
      def self.reasons(stage:, last_activity_on:, first_attached_on:, last_interaction_on:, overdue:, deactivated:, today:)
        return [] if deactivated || stage == :lost

        REASONS.select do |reason|
          case reason
          when :overdue then overdue
          when :usage_lost then last_activity_on && USAGE_LOST_RANGE.cover?((today - last_activity_on).to_i)
          when :demo_stalled then stage == :demo_done && (last_interaction_on.nil? || today - last_interaction_on >= DEMO_SILENCE)
          else first_attached_on && last_activity_on.nil? && today - first_attached_on > IDLE_AFTER # :registered_idle, dernier des REASONS
          end
        end
      end
    end
  end
end
