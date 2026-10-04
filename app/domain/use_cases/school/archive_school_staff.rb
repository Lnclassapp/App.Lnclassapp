# 🧠 DOMAINE · UseCases::School::ArchiveSchoolStaff
# Rôle : retirer un compte direction : archive son rattachement, ferme toutes ses sessions, journal school_staff.archived
# ADR  : 0028, 0071, 0077 (§4.3) · UDR : 0070 · utilisé par la direction (Lot B) et par l'équipe (Lot C)
module UseCases
  module School
    class ArchiveSchoolStaff
      # staff : le rattachement archivé (avant archivage) ; user : le compte, pour le nom du toast.
      Archived = Data.define(:staff, :user)
      ACTION = "school_staff.archived".freeze

      # Une archive perdue dans la course (deux onglets) traverse la transaction pour l'annuler, puis ressort en Result.
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("retrait annulé : #{result.code}")
        end
      end

      def initialize(staff:, schools:, users:, sessions:, audit_log:, policy:, transaction:, clock:)
        @staff = staff
        @schools = schools
        @users = users
        @sessions = sessions
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # target_public_id : public_id du compte retiré (users.public_id).
      # → success(Archived) | :not_found (cible absente, déjà archivée, ou d'un autre établissement pour une direction)
      #   | :forbidden (policy)
      def call(actor:, target_public_id:)
        target = @staff.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil? || target.archived?

        now = @clock.now
        allowed = @policy.call(actor:, school: @schools.find_by_id(id: target.school_id), target:, actor_staff: actor_staff(actor), now:)
        return allowed if allowed.failure?

        @transaction.call { archive(actor, target, now) }
      rescue Aborted => e
        e.result
      end

      private

      def actor_staff(actor) = actor&.school_admin? ? @staff.find_by_user_id(user_id: actor.user_id) : nil

      def archive(actor, target, now)
        raise Aborted, Shared::Result.failure(:not_found) unless @staff.archive(user_id: target.user_id, by_id: actor.user_id, at: now)

        @sessions.destroy_all_for(user_id: target.user_id)
        @audit_log.record(action: ACTION, actor_id: actor.user_id, at: now, subject_type: "User", subject_id: target.user_id,
                          metadata: { school_id: target.school_id, joined_via: target.joined_via })
        Shared::Result.success(Archived.new(staff: target, user: @users.find(id: target.user_id)))
      end
    end
  end
end
