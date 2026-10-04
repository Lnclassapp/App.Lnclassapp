# 🧠 DOMAINE · UseCases::School::PurgeArchivedStaff
# Rôle : la tâche du jour supprime chaque compte direction archivé avant l'échéance : anonymisé, sessions fermées,
#        rattachement supprimé, journal daté ; une transaction par compte
# ADR  : 0028, 0036 (§4), 0077 (§4.3, §4.5)
module UseCases
  module School
    class PurgeArchivedStaff
      def initialize(staffs:, users:, sessions:, audit_log:, transaction:, policy:, clock:)
        @staffs = staffs
        @users = users
        @sessions = sessions
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # at : l'échéance, archivés strictement avant (now - RETENTION_DAYS). → success(nombre supprimé) | :forbidden
      def call(at:, actor: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        now = @clock.now
        due = @staffs.archived_before(at:)
        due.each { |staff| @transaction.call { purge(staff, now) } }
        Shared::Result.success(due.size)
      end

      private

      # Le nom de l'ADR-0036 §4 : un compte supprimé se lit partout « Compte supprimé », son numéro est libéré.
      def purge(staff, now)
        @users.anonymize(user_id: staff.user_id, first_name: UseCases::Identity::AnonymizeUser::FIRST_NAME,
                         last_name: UseCases::Identity::AnonymizeUser::LAST_NAME, at: now)
        @sessions.destroy_all_for(user_id: staff.user_id)
        @staffs.delete(user_id: staff.user_id)
        @audit_log.record(action: "school_staff.deleted", actor_id: nil, at: now, subject_type: "User",
                          subject_id: staff.user_id, metadata: { school_id: staff.school_id })
      end
    end
  end
end
