require "test_helper"

# IL-05, IL-01 (ADR-0083 §4.3, ADR-0041): on PostgreSQL, the classroom row lock keeps the headcount right under
# concurrency — two sign-ups racing for the last seat, one by the cascade and one by the link, only one wins — and a
# membership refused after the account rolls both back.
class Classroom::JoinCapacityTest < ActiveSupport::TestCase
  # Two connections must see each other's commits: no wrapping test transaction.
  self.use_transactional_tests = false

  KEY = "k" * 32
  PAUSE = 0.5

  # Holds the lock a moment once taken, and says so: without the lock, the second sign-up would count the same headcount.
  class SlowLockClassrooms < Repositories::Classroom::ClassroomRepository
    def initialize(locked:)
      super()
      @locked = locked
    end

    def lock_by_public_id(public_id:)
      super.tap do
        @locked << true
        sleep PAUSE
      end
    end
  end

  class RefusedMemberships < Repositories::Classroom::MembershipRepository
    def add_primary(classroom_id:, student_id:, via:, at:)
      Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
    end
  end

  setup do
    @level = create_level(name: "3ème")
    @classroom = create_classroom(level: @level, name: "3e 2", max_students: 2)
    create_student(classroom: @classroom)
  end

  teardown do
    connection = ActiveRecord::Base.connection
    connection.truncate_tables(*(connection.tables - %w[schema_migrations ar_internal_metadata]))
  end

  def register(contact, link_token: nil, classrooms: Repositories::Classroom::ClassroomRepository.new,
               memberships: Repositories::Classroom::MembershipRepository.new)
    dto = Dtos::Classroom::StudentRegistrationInput.new(
      full_name: "KOUASSI Aya", gender: "female", contact:, pin: "4821", pin_confirmation: "4821", link_token:,
      school_public_id: @classroom.school.public_id, level_slug: @level.slug, classroom_public_id: @classroom.public_id
    )
    UseCases::Classroom::RegisterStudent.new(
      classrooms:, schools: Repositories::School::SchoolRepository.new, taxonomy: Repositories::Catalog::TaxonomyRepository.new,
      registrations: Repositories::Identity::RegistrationRepository.new, memberships:,
      sessions: Repositories::Identity::SessionRepository.new, policy: Policies::Classroom::JoinPolicy.new,
      transaction: Repositories::Shared::Transaction.new, digest_key: KEY, clock: Time.zone
    ).call(actor: nil, dto:, ip: "1.2.3.4", user_agent: "Chrome")
  end

  test "IL-05: two sign-ups racing for the last seat: only one is accepted, the other is told the classroom is full" do
    locked = Queue.new
    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { register("0701020301", classrooms: SlowLockClassrooms.new(locked:)) }
    end
    locked.pop(timeout: 10)
    token = @classroom.reload.link_token
    second = Thread.new { ActiveRecord::Base.connection_pool.with_connection { register("0701020302", link_token: token) } }
    results = [ first.value, second.value ]

    assert results.first.success?
    assert_equal [ :forbidden, { base: [ :classroom_full ] } ], [ results.last.code, results.last.errors ]
    assert_equal 2, Orm::ClassroomStudent.where(classroom: @classroom, left_at: nil).count
    assert_not Orm::User.exists?(contact: "0701020302"), "aucun compte pour l'inscription refusée"
  end

  test "IL-01: a membership refused after the account leaves neither the user, nor a membership, nor a session" do
    result = register("0701020303", memberships: RefusedMemberships.new)

    assert_equal :conflict, result.code
    assert_not Orm::User.exists?(contact: "0701020303")
    assert_equal 1, Orm::ClassroomStudent.count
    assert_equal 0, Orm::Session.count
  end
end
