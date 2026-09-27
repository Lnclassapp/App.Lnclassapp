# 🧠 DOMAINE · Policies::Identity::InviteTeamPolicy
# Rôle : seul un membre admin de l'équipe invite un nouveau membre
# ADR  : 0028, 0038
module Policies
  module Identity
    class InviteTeamPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team? && actor.team_role == "admin"

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
