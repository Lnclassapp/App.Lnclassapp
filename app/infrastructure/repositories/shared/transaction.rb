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

      # Une valeur déjà prise (index unique) est une collision : un nouvel essai, avec une autre valeur, peut aboutir. constraint : le nom de
      # la contrainte que PostgreSQL désigne, quand il en désigne une (jamais les valeurs en cause).
      def attempt_with_cause(&)
        ::Shared::Result.success(ActiveRecord::Base.transaction(requires_new: true, &))
      rescue *WRITE_FAILURES => error
        cause = error.is_a?(ActiveRecord::RecordNotUnique) ? :collision : :other
        errors = { base: [ :write_failed ], cause: [ cause ], exception: [ error.class.name ] }
        constraint = constraint_of(error)
        ::Shared::Result.failure(:conflict, errors: constraint ? errors.merge(constraint: [ constraint ]) : errors)
      end

      private

      def constraint_of(error)
        result = error.cause.respond_to?(:result) ? error.cause.result : nil
        result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      end
    end
  end
end
