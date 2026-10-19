require "test_helper"

# ID-04 (ADR-0077), at the use case level: six visitors register at once on the last place. One account is created; the
# five others are refused and their accounts, created before the cap check, are rolled back. ED-13 (ADR-0092 §4.3): two
# visitors register as head of school at once; one passes, the other gets the refusal of ED-12, never a 500. Threads need
# their own transactions, hence no test transaction.
class Identity::SchoolStaffRegistrationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ATTEMPTS = 6
  CONTACTS = Array.new(ATTEMPTS) { |index| format("070900%04d", index) }.freeze

  setup do
    @school = create_school(school_code: "k7m4qz")
    @existing = Array.new(2) { create_school_admin(school: @school, joined_via: "code") }
    @headless = create_school(school_code: "h3d7qa")
  end

  teardown do
    ids = Orm::User.where(contact: CONTACTS).ids + @existing.map(&:id)
    Orm::AuditEvent.where(subject_id: ids).delete_all
    Orm::Session.where(user_id: ids).delete_all
    Orm::SchoolStaff.where(user_id: ids).delete_all
    Orm::User.where(id: ids).delete_all
    drenas = [ @school.drena_id, @headless.drena_id ]
    [ @school, @headless ].each(&:delete)
    Orm::Drena.where(id: drenas).delete_all
  end

  def register(contact, position: "secretary", school_code: "K7M-4QZ")
    dto = Dtos::Identity::SchoolStaffRegistrationInput.new(last_name: "Kouassi", first_name: "Aya", gender: "female", contact:,
                                                           pin: "2468", pin_confirmation: "2468", school_code:, position:)
    UseCases::Identity::RegisterSchoolStaff.new(
      registrations: Repositories::Identity::RegistrationRepository.new, schools: Repositories::School::SchoolRepository.new,
      staffs: Repositories::School::StaffRepository.new, sessions: Repositories::Identity::SessionRepository.new,
      audit_log: Repositories::Identity::AuditLogRepository.new, policy: Policies::Identity::RegisterSchoolStaffPolicy.new,
      transaction: Repositories::Shared::Transaction.new, digest_key: "test-key", clock: Time.zone
    ).call(actor: nil, dto:, ip: "10.0.0.1", user_agent: "test")
  end

  test "six simultaneous registrations on the third place: one account, five refusals rolled back" do
    gate = Queue.new
    threads = CONTACTS.map do |contact|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { register(contact) }
      end
    end
    ATTEMPTS.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal [ :conflict ] * 5, results.reject(&:success?).map(&:code)
    assert_equal 1, Orm::User.where(contact: CONTACTS).count
    assert_equal 1, Orm::AuditEvent.where(action: "school_staff.registered").count
    assert_equal 3, Orm::SchoolStaff.active.where(school: @school, joined_via: "code").count
  end

  test "ED-13: two simultaneous registrations as head of school: one head, the other refused on the position, rolled back" do
    gate = Queue.new
    threads = CONTACTS.first(2).map do |contact|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { register(contact, position: "head", school_code: "H3D-7QA") }
      end
    end
    2.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    refused = results.reject(&:success?).sole
    assert_equal [ :conflict, { position: [ :head_taken ] } ], [ refused.code, refused.errors ]
    assert_equal 1, Orm::User.where(contact: CONTACTS).count
    assert_equal [ "head" ], Orm::SchoolStaff.active.where(school: @headless).pluck(:position)
  end
end
