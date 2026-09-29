# A test that changes the schema (a migration run down then up) moves the column it drops and adds back to the end of
# its table: `SELECT schools.*` changes shape, and PostgreSQL refuses, inside a transaction, every statement prepared
# before it (« cached plan must not change result type »). Rails forgets the statements of the connection that ran the
# DDL only; another one left idle in the pool by a test with threads kept its own, and failed the next test that took
# it (chantier tests-instables). Every schema change of a test goes through this block, which forgets them all.
module SchemaChangeHelper
  ActiveSupport::TestCase.include(self)

  def changing_schema
    yield
  ensure
    ActiveRecord::Base.connection_pool.connections.each(&:clear_cache!)
  end
end
