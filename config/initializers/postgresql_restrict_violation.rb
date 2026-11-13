# frozen_string_literal: true

# PostgreSQL 18 signale le refus d'une clé étrangère ON DELETE RESTRICT par le code 23001
# (restrict_violation) au lieu de 23503 (foreign_key_violation). Rails 8.1 ne connaît que 23503 :
# sans ce relais, le refus remonte en ActiveRecord::StatementInvalid et échappe aux rescue
# d'InvalidForeignKey. On le traduit comme avant, quelle que soit la version du serveur.
module PostgresqlRestrictViolation
  RESTRICT_VIOLATION = "23001"

  private

  def translate_exception(exception, message:, sql:, binds:)
    if exception.respond_to?(:result) && exception.result.try(:error_field, PG::PG_DIAG_SQLSTATE) == RESTRICT_VIOLATION
      return ActiveRecord::InvalidForeignKey.new(message, sql:, binds:, connection_pool: @pool)
    end

    super
  end
end

ActiveSupport.on_load(:active_record_postgresqladapter) { prepend PostgresqlRestrictViolation }
