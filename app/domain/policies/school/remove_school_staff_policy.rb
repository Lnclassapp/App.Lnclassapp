# 🧠 DOMAINE · Policies::School::RemoveSchoolStaffPolicy
# Rôle : retirer un compte direction : l'équipe admin/field partout ; une autre direction du même établissement actif, après 7 jours
# ADR  : 0028, 0071, 0077 (§4.3, §6)
module Policies
  module School
    class RemoveSchoolStaffPolicy
      TEAM_ROLES = %w[admin field].freeze

      # actor_staff : le rattachement de l'acteur s'il est direction (nil sinon) ; target : Entities::School::Staff (ou ce qui
      # répond à school_id et user_id) ; school : l'établissement de la cible.
      # → success | :forbidden | :not_found (cible d'un autre établissement, comme ADR-0071)
      def call(actor:, school:, target:, actor_staff:, now:)
        return Shared::Result.success if actor&.team? && TEAM_ROLES.include?(actor.team_role)
        return Shared::Result.failure(:forbidden) unless actor&.school_admin? && actor_staff && !actor_staff.archived?
        return Shared::Result.failure(:not_found) unless target.school_id == actor.school_id
        return Shared::Result.failure(:forbidden) if !school&.active? || target.user_id == actor.user_id || actor_staff.newcomer?(now)

        Shared::Result.success
      end
    end
  end
end
