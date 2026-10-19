# 🧠 DOMAINE · Entities::Identity::Actor
# Rôle : celui qui agit, construit depuis la session ; un visiteur est `actor: nil` ; la fonction d'une direction
# ADR  : 0028, 0038, 0092
module Entities
  module Identity
    Actor = Data.define(:user_id, :role, :team_role, :school_id, :staff_position) do
      # staff_position : la fonction d'une direction (Entities::School::StaffPosition), nil pour tout autre rôle (ADR-0092).
      # Un acteur de direction sans fonction n'a que les lectures (StaffPosition.management? le refuse).
      def initialize(user_id:, role:, team_role: nil, school_id: nil, staff_position: nil)
        raise ArgumentError, "rôle inconnu : #{role.inspect}" unless Actor::ROLES.include?(role)

        super
      end

      def student? = role == :student
      def teacher? = role == :teacher
      def school_admin? = role == :school_admin
      def team? = role == :team
      # Direction de rang « gestion » (chef d'établissement, adjoint ou directeur des études), ADR-0092 §4.3.
      def school_management? = school_admin? && Entities::School::StaffPosition.management?(staff_position)
    end
    Actor::ROLES = %i[student teacher school_admin team].freeze
  end
end
