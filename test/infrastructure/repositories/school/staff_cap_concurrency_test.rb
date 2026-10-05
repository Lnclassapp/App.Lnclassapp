require "test_helper"

# ID-04 (ADR-0077): two sign-ups by code on the last place of a school serialize on the school row: one passes.
# Outside any test transaction: threads need their own.
class StaffCapConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ATTEMPTS = 6

  setup do
    @school = create_school
    @existing = Array.new(2) { create_school_admin(school: @school, joined_via: "code") }
    @candidates = Array.new(ATTEMPTS) { create_user(role: "school_admin") }
  end

  teardown do
    ids = (@existing + @candidates).map(&:id)
    Orm::SchoolStaff.where(user_id: ids).delete_all
    Orm::User.where(id: ids).delete_all
    drena = @school.drena_id
    @school.delete
    Orm::Drena.where(id: drena).delete_all
  end

  test "six simultaneous sign-ups on the third place: exactly one is attached" do
    gate = Queue.new
    threads = @candidates.map do |candidate|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection do
          Repositories::School::StaffRepository.new.attach_by_code(user_id: candidate.id, school_id: @school.id, cap: 3,
                                                                    at: Time.current)
        end
      end
    end
    ATTEMPTS.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(true)
    assert_equal 3, Orm::SchoolStaff.where(school: @school, joined_via: "code").count
  end
end
