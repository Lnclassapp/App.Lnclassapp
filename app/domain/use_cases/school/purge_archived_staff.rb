# 🧠 DOMAINE · UseCases::School::PurgeArchivedStaff
# Rôle : la tâche du jour supprime chaque compte direction archivé avant l'échéance : tout ce qu'efface AnonymizeUser pour
#        un compte sans classe, puis le rattachement ; journal daté ; une transaction par compte
# ADR  : 0028, 0036 (§4), 0077 (§4.3, §4.5)
module UseCases
  module School
    class PurgeArchivedStaff
      # deleted : comptes supprimés ; failed : user_id des comptes en échec, rejoués la nuit suivante (aucune donnée personnelle).
      Purged = Data.define(:deleted, :failed)

      def initialize(staffs:, users:, sessions:, photos:, login_attempts:, second_factors:, pin_recoveries:, audit_log:,
                     transaction:, policy:, clock:)
        @staffs = staffs
        @users = users
        @sessions = sessions
        @photos = photos
        @login_attempts = login_attempts
        @second_factors = second_factors
        @pin_recoveries = pin_recoveries
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # at : l'échéance, archivés strictement avant (now - RETENTION_DAYS). → success(Purged) | :forbidden
      # Un compte en échec n'arrête pas les suivants : sa transaction est annulée, il reste archivé et repasse le lendemain.
      def call(at:, actor: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        now = @clock.now
        due = @staffs.archived_before(at:)
        failed = due.filter_map { |staff| staff.user_id unless purged?(staff, now) }
        Shared::Result.success(Purged.new(deleted: due.size - failed.size, failed:))
      end

      private

      def purged?(staff, now)
        @transaction.call { purge(staff, now) }
        true
      rescue StandardError
        false
      end

      # L'ordre d'AnonymizeUser, sans adhésions ni données d'apprentissage, propres aux élèves (ADR-0077 §4.3 amendé). Le nom
      # de l'ADR-0036 §4 : « Compte supprimé ». Les tentatives de connexion portent le numéro, lu avant d'être effacé.
      def purge(staff, now)
        user_id = staff.user_id
        contact = @users.find(id: user_id).contact
        @photos.remove(user_id:)
        @login_attempts.destroy_all_for(user_id:, contact:)
        @users.anonymize(user_id:, first_name: UseCases::Identity::AnonymizeUser::FIRST_NAME,
                         last_name: UseCases::Identity::AnonymizeUser::LAST_NAME, at: now)
        @sessions.destroy_all_for(user_id:)
        @second_factors.reset(user_id:)
        @pin_recoveries.destroy_all_for(user_id:)
        @staffs.delete(user_id:)
        @audit_log.record(action: "school_staff.deleted", actor_id: nil, at: now, subject_type: "User", subject_id: user_id,
                          metadata: { school_id: staff.school_id })
      end
    end
  end
end
