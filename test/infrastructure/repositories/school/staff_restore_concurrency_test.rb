require "test_helper"

# Revue de sécurité du Lot C (ADR-0077) : les restaurations se sérialisent sur l'établissement, entre elles, avec le plafond
# et avec la suppression à J+30. Hors transaction de test : chaque thread a la sienne.
class StaffRestoreConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @school = create_school
    @users = []
  end

  teardown do
    ids = @users.map(&:id)
    Orm::AuditEvent.where(subject_id: ids).delete_all
    Orm::Session.where(user_id: ids).delete_all
    Orm::SchoolStaff.where(user_id: ids).delete_all
    Orm::User.where(id: ids).delete_all
    drena = @school.drena_id
    @school.delete
    Orm::Drena.where(id: drena).delete_all
  end

  def admin(archived_at: nil, **attributes)
    create_school_admin(school: @school, archived_at:, archived_by: (@author if archived_at), **attributes).tap { @users << it }
  end

  def together(count, &block)
    gate = Queue.new
    threads = Array.new(count) do |index|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { block.call(index) }
      end
    end
    count.times { gate << true }
    threads.map(&:value)
  end

  def repository = Repositories::School::StaffRepository.new

  test "five simultaneous restorations of one account: exactly one :restored" do
    @author = create_team_member(second_factor: false).tap { @users << it }
    aya = admin(archived_at: 1.day.ago)

    results = together(5) { repository.restore(user_id: aya.id, cap: 3) }

    assert_equal 1, results.count(:restored)
    assert_equal 4, results.count(:not_archived)
  end

  test "two places taken, two code arrivals restored at once: one passes, the cap holds" do
    @author = create_team_member(second_factor: false).tap { @users << it }
    2.times { admin(joined_via: "code") }
    archived = Array.new(2) { admin(joined_via: "code", archived_at: 1.day.ago) }

    results = together(2) { |index| repository.restore(user_id: archived[index].id, cap: 3) }

    assert_equal [ :cap_reached, :restored ], results.sort
    assert_equal 3, Orm::SchoolStaff.active.where(school: @school, joined_via: "code").count
  end

  def waiting_on_a_lock?(sql)
    # Hors cache de requêtes : la même requête rejouée renverrait sinon toujours sa première réponse.
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.uncached { connection.select_value(sql) } }
  end

  # Attend, sans durée arbitraire, qu'une autre connexion soit réellement bloquée sur un verrou : c'est l'état que le test veut observer.
  def wait_until_a_backend_waits_on_a_lock(timeout: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    sql = "SELECT 1 FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock' AND pid <> pg_backend_pid()"
    until waiting_on_a_lock?(sql)
      flunk "aucune purge n'attend le verrou de l'établissement après #{timeout} s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      Thread.pass
    end
  end

  # Ordre imposé, pas espéré : (1) la restauration prend le verrou de l'établissement, sa transaction reste ouverte ;
  # (2) la purge démarre et se bloque sur ce verrou ; (3) seulement alors la restauration valide. La purge relit la ligne
  # sous le verrou et doit la trouver restaurée. Avant : le signal partait avant la prise du verrou, et sous charge la purge
  # pouvait le prendre la première (1 compte supprimé au lieu de 0).
  test "a restoration that commits first takes the account out of the 30-day purge" do
    @author = create_team_member(second_factor: false).tap { @users << it }
    aya = admin(first_name: "Aya", archived_at: 31.days.ago)
    lock_held = Queue.new
    commit = Queue.new

    restorer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Orm::SchoolStaff.transaction do
          result = repository.restore(user_id: aya.id, cap: 3) # rejoint la transaction : le verrou tient jusqu'à son commit
          lock_held << true
          commit.pop
          result
        end
      end
    end
    purger = nil
    begin
      assert lock_held.pop(timeout: 10), "la restauration n'a pas pris le verrou"
      purger = Thread.new { ActiveRecord::Base.connection_pool.with_connection { School::PurgeArchivedStaffJob.perform_now } }
      wait_until_a_backend_waits_on_a_lock
    ensure
      commit << true
    end

    assert_equal :restored, restorer.value
    assert_equal 0, purger.value
    assert_equal "Aya", aya.reload.first_name
    assert_nil Orm::SchoolStaff.find_by!(user_id: aya.id).archived_at
  end
end
