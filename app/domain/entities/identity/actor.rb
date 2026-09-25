# 🧠 DOMAINE · Entities::Identity::Actor
# Rôle : celui qui agit, construit depuis la session ; un visiteur est `actor: nil`
# ADR  : 0028, 0038
module Entities
  module Identity
    Actor = Data.define(:user_id, :role, :team_role, :school_id) do
      def initialize(user_id:, role:, team_role: nil, school_id: nil)
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
