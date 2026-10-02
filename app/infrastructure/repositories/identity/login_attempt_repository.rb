# 🔌 INFRA · Repositories::Identity::LoginAttemptRepository
# Rôle : journal des tentatives de PIN et de second facteur, base du verrouillage progressif
# ADR  : 0031, 0032, 0050
module Repositories
  module Identity
    class LoginAttemptRepository
      include Ports::Identity::LoginAttemptRepositoryPort

      CONTACT_LIMIT = 20

      def record(contact:, user_id:, ip:, succeeded:, kind:, at:)
        raise ArgumentError, "type de tentative inconnu : #{kind.inspect}" unless KINDS.include?(kind)

        Orm::LoginAttempt.create!(contact: contact.to_s.first(CONTACT_LIMIT), user_id:, succeeded:, kind:,
                                  ip_address: ip.to_s.first(45).presence, created_at: at)
        true
      end

      def consecutive_failures(contact:, kind:)
        attempts = Orm::LoginAttempt.where(contact: contact.to_s.first(CONTACT_LIMIT), kind:)
        last_success = attempts.where(succeeded: true).maximum(:created_at)
        failures = attempts.where(succeeded: false)
        failures = failures.where("login_attempts.created_at > ?", last_success) if last_success
        count, last_failed_at = failures.pick(Arel.sql("COUNT(*)"), Arel.sql("MAX(created_at)"))
        Failures.new(count:, last_failed_at:)
      end

      # Tous les types : un PIN réinitialisé lève aussi le verrou du second facteur.
      def clear_failures(contact:)
        Orm::LoginAttempt.where(contact: contact.to_s.first(CONTACT_LIMIT), succeeded: false).delete_all
      end

      # Le numéro libéré ne doit pas léguer ses échecs, ni son verrou, à qui le reprendra.
      def destroy_all_for(user_id:, contact:)
        attempts = Orm::LoginAttempt.where(user_id:)
        attempts = attempts.or(Orm::LoginAttempt.where(contact: contact.to_s.first(CONTACT_LIMIT))) if contact.present?
        attempts.delete_all
      end
    end
  end
end
