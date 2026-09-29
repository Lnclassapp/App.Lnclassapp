require "test_helper"

# Chantier tests-instables : un test qui migre (down puis up) déplace une colonne en fin de table. `SELECT schools.*`
# change alors de forme, et PostgreSQL refuse toute requête préparée avant, dans une transaction : « cached plan must
# not change result type ». Rails n'oublie que les requêtes de la connexion qui a joué le DDL ; une autre connexion,
# restée libre dans le pool après un test à plusieurs fils, gardait les siennes et faisait échouer le test suivant.
class SchemaChangeHelperTest < ActiveSupport::TestCase
  # Deux connexions et un DDL : pas de transaction de test englobante.
  self.use_transactional_tests = false

  def pool = ActiveRecord::Base.connection_pool

  # Lit l'école depuis deux fils à la fois, chacun dans sa transaction comme un use case : le pool ouvre ou reprend
  # deux connexions, dont au moins une n'est pas celle qui jouera ou a joué le DDL.
  def read_on_two_connections(id)
    both = Queue.new
    threads = Array.new(2) do
      Thread.new do
        pool.with_connection do
          Orm::School.transaction do
            both << true
            sleep 0.01 until both.size == 2
            Orm::School.find(id).id
          end
        end
      end
    end
    threads.map(&:value)
  end

  teardown do
    changing_schema { ActiveRecord::Base.connection.remove_column :schools, :probe, if_exists: true }
    Orm::School.reset_column_information
    Orm::School.where(id: @school.id).delete_all
    Orm::Drena.where(id: @school.drena_id).delete_all
  end

  test "after a schema change, a connection left idle in the pool reads the reshaped table inside a transaction" do
    @school = create_school
    assert_equal [ @school.id ] * 2, read_on_two_connections(@school.id)

    changing_schema { ActiveRecord::Base.connection.add_column :schools, :probe, :string }
    Orm::School.reset_column_information

    assert_equal [ @school.id ] * 2, read_on_two_connections(@school.id)
  end
end
