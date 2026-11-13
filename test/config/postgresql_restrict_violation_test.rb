require "test_helper"

# PostgreSQL 18 refuse une suppression sous ON DELETE RESTRICT avec le code 23001 ; l'application
# doit continuer d'y lire une ActiveRecord::InvalidForeignKey, comme avec le code 23503 d'avant.
class PostgresqlRestrictViolationTest < ActiveSupport::TestCase
  def raise_sqlstate(code)
    ActiveRecord::Base.connection.execute("DO $$ BEGIN RAISE EXCEPTION 'refus' USING ERRCODE = '#{code}'; END $$")
  end

  test "un refus RESTRICT (23001) devient une InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { raise_sqlstate("23001") }
  end

  test "un refus de clé étrangère classique (23503) reste une InvalidForeignKey" do
    assert_raises(ActiveRecord::InvalidForeignKey) { raise_sqlstate("23503") }
  end

  test "les autres erreurs ne sont pas touchées" do
    error = assert_raises(ActiveRecord::StatementInvalid) { raise_sqlstate("P0001") }
    assert_not_kind_of ActiveRecord::InvalidForeignKey, error
  end
end
