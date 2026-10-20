# 🔌 INFRA · Repositories::Shared::Transaction
# Rôle : transaction ouverte par un use case ; `attempt` traduit un refus de la base en :conflict
# ADR  : 0026, 0039, 0096
module Repositories
  module Shared
    class Transaction
      include Ports::Shared::TransactionPort

      WRITE_FAILURES = [
        ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey,
        ActiveRecord::NotNullViolation, ActiveRecord::CheckViolation, ActiveRecord::LockWaitTimeout,
        ActiveRecord::RangeError
      ].freeze

      def call(&) = ActiveRecord::Base.transaction(&)

      # requires_new : dans une transaction englobante, seul ce point de sauvegarde est annulé.
      def attempt(&)
        written = attempt_with_cause(&)
        written.success? ? written : ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      end

      # Une valeur déjà prise (index unique) est une collision : un nouvel essai, avec une autre valeur, peut aboutir.
      def attempt_with_cause(&)
        ::Shared::Result.success(ActiveRecord::Base.transaction(requires_new: true, &))
      rescue *WRITE_FAILURES => error
        cause = error.is_a?(ActiveRecord::RecordNotUnique) ? :collision : :other
        ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ], cause: [ cause ], exception: [ error.class.name ] })
      end
    end
  end
end
