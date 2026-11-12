# 🧠 DOMAINE · Policies::Crm::ManageCrmPolicy
# Rôle : lire et écrire le suivi des écoles : l'équipe `admin` et `field` seuls (écart voulu avec ManageSchoolPolicy, qui admet `content`)
# ADR  : XXXX (contexte crm), 0038
module Policies
  module Crm
    class ManageCrmPolicy
      TEAM_ROLES = %w[admin field].freeze

      def call(actor:)
        return Shared::Result.success(actor) if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
