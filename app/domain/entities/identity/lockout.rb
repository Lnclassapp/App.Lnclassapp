# 🧠 DOMAINE · Entities::Identity::Lockout
# Rôle : verrouillage jusqu'à récupération au 5e échec consécutif depuis le dernier succès (décision du porteur, 2026-11-24)
# ADR  : 0050, 0032
module Entities
  module Identity
    module Lockout
      UNTIL_RECOVERY = :until_recovery
      TIERS = { 5 => UNTIL_RECOVERY }.freeze

      # nil si la tentative est permise ; sinon le temps restant, ou :until_recovery.
      def self.retry_after(failures:, last_failed_at:, now:)
        duration = TIERS.find { |threshold, _| failures >= threshold }&.last
        return duration if duration.nil? || duration == UNTIL_RECOVERY

        remaining = (last_failed_at + duration - now).ceil
        ActiveSupport::Duration.build(remaining) if remaining.positive?
      end

      # Vrai quand ce nombre d'échecs vient de franchir un palier (audit `login.locked`).
      def self.tier_reached?(failures) = TIERS.key?(failures)
    end
  end
end
