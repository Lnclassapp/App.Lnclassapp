# 🔌 INFRA · Repositories::Identity::SecondFactorRepository
# Rôle : second facteur TOTP (rotp, secret chiffré) et codes de secours à usage unique
# ADR  : 0031
module Repositories
  module Identity
    class SecondFactorRepository
      include Ports::Identity::SecondFactorRepositoryPort

      ISSUER = "Lnclass".freeze
      INTERVAL = 30

      def state_for(user_id:)
        confirmed_at = Orm::TotpCredential.where(user_id:).pluck(:confirmed_at)
        return if confirmed_at.empty?

        State.new(confirmed: !confirmed_at.first.nil?, backup_codes_left: Orm::BackupCode.where(user_id:, used_at: nil).count)
      end

      # Un secret confirmé n'est jamais remplacé : l'index unique refuse la nouvelle ligne.
      def begin_enrollment(user_id:, label:)
        secret = ROTP::Base32.random
        Orm::TotpCredential.where(user_id:, confirmed_at: nil).delete_all
        Orm::TotpCredential.create!(user_id:, secret:)
        Enrollment.new(secret:, provisioning_uri: ROTP::TOTP.new(secret, issuer: ISSUER).provisioning_uri(label))
      end

      # Le pas n'est enregistré que s'il dépasse le dernier accepté : un code rejoué, même en parallèle, est refusé.
      def verify_code(user_id:, code:, now:)
        credential = Orm::TotpCredential.find_by(user_id:)
        return if credential.nil?

        accepted_at = ROTP::TOTP.new(credential.secret).verify(code.to_s, drift_behind: INTERVAL, drift_ahead: INTERVAL, at: now.to_i)
        return if accepted_at.nil?

        step = accepted_at / INTERVAL
        claimed = Orm::TotpCredential.where(id: credential.id)
                                     .where("last_used_step IS NULL OR last_used_step < ?", step)
                                     .update_all(last_used_step: step, updated_at: now)
        step if claimed == 1
      end

      def confirm(user_id:, backup_code_digests:, at:)
        Orm::TotpCredential.where(user_id:).update_all(confirmed_at: at, updated_at: at)
        Orm::BackupCode.where(user_id:).delete_all
        Orm::BackupCode.insert_all!(backup_code_digests.map { { user_id:, code_digest: it, created_at: at } })
        true
      end

      def consume_backup_code(user_id:, code_digest:, at:)
        Orm::BackupCode.where(user_id:, code_digest:, used_at: nil).update_all(used_at: at).positive?
      end

      def reset(user_id:)
        Orm::BackupCode.where(user_id:).delete_all
        Orm::TotpCredential.where(user_id:).delete_all
        true
      end
    end
  end
end
