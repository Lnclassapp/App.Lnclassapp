# 🧠 DOMAINE · Policies::School::SetStaffPositionPolicy
# Rôle : changer la fonction d'une direction : l'équipe admin ou field seulement ; aucune direction, ni la sienne ni une autre
# ADR  : 0028, 0092 (§4.3) · UDR : 0092 (§3.4) · une direction qui se dirait chef ne se promeut pas seule (memo, Q2)
module Policies
  module School
    class SetStaffPositionPolicy
      TEAM_ROLES = %w[admin field].freeze

      # → success | :forbidden
      def call(actor:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
