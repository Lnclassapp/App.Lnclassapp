# 🧠 DOMAINE · UseCases::School::RestoreSchoolStaff
# Rôle : l'équipe restaure un compte direction retiré : sous le plafond pour une arrivée par le code, journal school_staff.restored
# ADR  : 0028, 0077 (§4.2, §4.3) · UDR : 0070 (§3.5) · le plafond est compté par le repository, sous le verrou de l'établissement
module UseCases
  module School
    class RestoreSchoolStaff
      # staff : le rattachement restauré (avant restauration) ; user : le compte, pour le nom du toast.
      Restored = Data.define(:staff, :user)
      ACTION = "school_staff.restored".freeze

      def initialize(staff:, users:, audit_log:, policy:, transaction:, clock:)
        @staff = staff
        @users = users
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # target_public_id : public_id du compte à restaurer (users.public_id).
      # → success(Restored) | :forbidden (policy) | :not_found (cible absente ou plus archivée)
      #   | failure(:conflict, errors: { base: [:cap_reached] }) (3 directions actives par le code, pour une arrivée par le code)
      def call(actor:, target_public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        target = @staff.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        @transaction.call { restore(actor, target) }
      end

      private

      def restore(actor, target)
        case @staff.restore(user_id: target.user_id, cap: Entities::School::Staff::CODE_CAP)
        when :cap_reached then Shared::Result.failure(:conflict, errors: { base: [ :cap_reached ] })
        when :not_archived then Shared::Result.failure(:not_found)
        else
          @audit_log.record(action: ACTION, actor_id: actor.user_id, at: @clock.now, subject_type: "User", subject_id: target.user_id,
                            metadata: { school_id: target.school_id, joined_via: target.joined_via })
          Shared::Result.success(Restored.new(staff: target, user: @users.find(id: target.user_id)))
        end
      end
    end
  end
end
