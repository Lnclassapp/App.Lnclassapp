# 🔌 INFRA · Repositories::Shared::Transaction
# Rôle : transaction ouverte par un use case ; `attempt` traduit un refus de la base en :conflict
# ADR  : 0026, 0039
module Repositories
  module Shared
    class Transaction
      include Ports::Shared::TransactionPort

      WRITE_FAILURES = [
        ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey,
        ActiveRecord::NotNullViolation, ActiveRecord::CheckViolation, ActiveRecord::LockWaitTimeout
      ].freeze

      def call(&) = ActiveRecord::Base.transaction(&)

      # requires_new : dans une transaction englobante, seul ce point de sauvegarde est annulé.
      def attempt(&)
        ::Shared::Result.success(ActiveRecord::Base.transaction(requires_new: true, &))
      rescue *WRITE_FAILURES
        ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      end
    end
  end
end
