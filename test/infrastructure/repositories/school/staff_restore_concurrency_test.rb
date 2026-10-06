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

  test "a restoration that commits first takes the account out of the 30-day purge" do
    @author = create_team_member(second_factor: false).tap { @users << it }
    aya = admin(first_name: "Aya", archived_at: 31.days.ago)
    restoring = Queue.new
    restored = Queue.new

    restorer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Orm::SchoolStaff.transaction do
          restoring << true
          repository.restore(user_id: aya.id, cap: 3).tap { sleep 0.3 }
        end
      end.tap { restored << true }
    end
    restoring.pop
    purged = ActiveRecord::Base.connection_pool.with_connection { School::PurgeArchivedStaffJob.perform_now }
    restorer.join

    assert_equal 0, purged
    assert_equal "Aya", aya.reload.first_name
    assert_nil Orm::SchoolStaff.find_by!(user_id: aya.id).archived_at
  end
end
