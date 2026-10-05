require "test_helper"

# Revue de sécurité, constat 3 (ADR-0077) : deux directions qui se retirent l'une l'autre en même temps se sérialisent sur
# l'établissement ; une seule y parvient, l'établissement garde une direction. Hors transaction de test : chaque thread la sienne.
class StaffMutualRemovalConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @school = create_school
    @kofi, @aya = Array.new(2) { create_school_admin(school: @school, joined_at: 10.days.ago) }
  end

  teardown do
    ids = [ @kofi, @aya ].map(&:id)
    Orm::AuditEvent.where(subject_id: ids).delete_all
    Orm::SchoolStaff.where(user_id: ids).delete_all
    Orm::User.where(id: ids).delete_all
    drena = @school.drena_id
    @school.delete
    Orm::Drena.where(id: drena).delete_all
  end

  # La policy passe pour les deux, puis attend : les deux retraits entrent ensemble dans leur transaction.
  class SlowPolicy < Policies::School::RemoveSchoolStaffPolicy
    def call(**)
      super.tap { sleep 0.3 }
    end
  end

  def archive(actor_user, target_user)
    actor = Entities::Identity::Actor.new(user_id: actor_user.id, role: :school_admin, school_id: @school.id)
    UseCases::School::ArchiveSchoolStaff.new(
      staff: Repositories::School::StaffRepository.new, schools: Repositories::School::SchoolRepository.new,
      users: Repositories::Identity::UserRepository.new, sessions: Repositories::Identity::SessionRepository.new,
      audit_log: Repositories::Identity::AuditLogRepository.new, policy: SlowPolicy.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(actor:, target_public_id: target_user.public_id)
  end

  test "Kofi removes Aya while Aya removes Kofi: exactly one removal passes" do
    gate = Queue.new
    threads = [ [ @kofi, @aya ], [ @aya, @kofi ] ].map do |actor, target|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { archive(actor, target) }
      end
    end
    2.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal 1, Orm::SchoolStaff.active.where(school: @school).count
  end
end
