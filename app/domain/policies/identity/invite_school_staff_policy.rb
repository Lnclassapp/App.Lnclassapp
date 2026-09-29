# 🧠 DOMAINE · Policies::Identity::InviteSchoolStaffPolicy
# Rôle : un membre admin ou terrain de l'équipe invite la direction d'un établissement
# ADR  : 0028, 0038, 0065
module Policies
  module Identity
    class InviteSchoolStaffPolicy
      TEAM_ROLES = %w[admin field].freeze

      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
