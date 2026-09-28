# 🧠 DOMAINE · Entities::Identity::Actor
# Rôle : celui qui agit, construit depuis la session ; un visiteur est `actor: nil`
# ADR  : 0028, 0038, 0066
module Entities
  module Identity
    # school_id : école principale d'un enseignant, établissement du rattachement actif d'un membre de la direction ;
    # position : fonction de ce membre (Entities::School::StaffPosition::ALL), nil pour les autres rôles.
    Actor = Data.define(:user_id, :role, :team_role, :school_id, :position) do
      def initialize(user_id:, role:, team_role: nil, school_id: nil, position: nil)
        raise ArgumentError, "rôle inconnu : #{role.inspect}" unless Actor::ROLES.include?(role)

        super
      end

      def student? = role == :student
      def teacher? = role == :teacher
      def school_admin? = role == :school_admin
      def team? = role == :team
    end
    Actor::ROLES = %i[student teacher school_admin team].freeze
  end
end
