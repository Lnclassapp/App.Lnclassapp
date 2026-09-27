# 🧠 DOMAINE · Entities::Identity::SessionLifetime
# Rôle : expiration d'une session par inactivité et par ancienneté selon le rôle
# ADR  : 0050
module Entities
  module Identity
    module SessionLifetime
      IDLE_TTL = 30.days
      ABSOLUTE_TTL = { team: 12.hours, school_admin: 12.hours }.freeze
      TOUCH_EVERY = 5.minutes

      def self.expired?(role:, created_at:, last_seen_at:, now:)
        return true if now >= last_seen_at + IDLE_TTL

        absolute = ABSOLUTE_TTL[role.to_sym]
        !absolute.nil? && now >= created_at + absolute
      end

      def self.touch_due?(last_seen_at:, now:) = now >= last_seen_at + TOUCH_EVERY
    end
  end
end
