# 🧠 DOMAINE · Policies::School::RestoreSchoolStaffPolicy
# Rôle : restaurer un compte direction retiré, avant sa suppression : l'équipe admin ou field seulement
# ADR  : 0028, 0077 (§4.3) · UDR : 0070 (§3.5) · aucune direction ne se restaure elle-même, ni une autre
module Policies
  module School
    class RestoreSchoolStaffPolicy
      TEAM_ROLES = %w[admin field].freeze

      # → success | :forbidden
      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
