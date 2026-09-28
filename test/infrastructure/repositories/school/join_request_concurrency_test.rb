require "test_helper"

# B2 (ADR-0063): the cap of pending requests per school holds under concurrent sign-ups — the count and the insert run
# under a lock on the school row, in the sign-up transaction. Outside any test transaction: threads need their own.
class JoinRequestConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ATTEMPTS = 12
  MAX = 5

  setup do
    @school = create_school
    @teachers = Array.new(ATTEMPTS) { create_teacher(school: nil) }
  end

  teardown do
    Orm::SchoolJoinRequest.where(school: @school).delete_all
    ids = @teachers.map(&:id)
    profiles = Orm::TeacherProfile.where(user_id: ids)
    materials = profiles.pluck(:material_id)
    profiles.delete_all
    Orm::User.where(id: ids).delete_all
    Orm::Material.where(id: materials).delete_all
    drena = @school.drena_id
    @school.delete
    Orm::Drena.where(id: drena).delete_all
  end

  test "twelve simultaneous requests for one school: exactly five are pending" do
    gate = Queue.new
    threads = @teachers.map do |teacher|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection do
          Repositories::Shared::Transaction.new.call do
            Repositories::School::JoinRequestRepository.new.create(teacher_id: teacher.id, school_id: @school.id,
                                                                   at: Time.current, max_pending: MAX).tap { sleep 0.05 }
          end
        end
      end
    end
    ATTEMPTS.times { gate << true }
    results = threads.map(&:value)

    assert_equal MAX, Orm::SchoolJoinRequest.where(school: @school, status: "pending").count
    assert_equal ATTEMPTS - MAX, results.count(&:failure?)
  end
end
