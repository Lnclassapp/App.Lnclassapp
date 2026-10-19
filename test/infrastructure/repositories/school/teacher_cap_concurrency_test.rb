require "test_helper"

# ME-04 (ADR-0094 §4.5): simultaneous « Rejoindre » of a teacher with two schools serialize on the users row: never more
# than three schools. Outside any test transaction: threads need their own.
class TeacherCapConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  ATTEMPTS = 5

  setup do
    @drena = create_drena
    @existing = Array.new(2) { create_school(drena: @drena) }
    @targets = Array.new(ATTEMPTS) { create_school(drena: @drena) }
    @teacher = create_teacher(school: @existing.first)
    Orm::TeacherSchool.create!(teacher: @teacher, school: @existing.last, primary: false)
  end

  teardown do
    Orm::TeacherSchool.where(teacher_id: @teacher.id).delete_all
    materials = Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).pluck(:material_id)
    Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).delete_all
    Orm::TeacherProfile.where(user_id: @teacher.id).delete_all
    Orm::User.where(id: @teacher.id).delete_all
    Orm::Material.where(id: materials).delete_all
    Orm::School.where(id: (@existing + @targets).map(&:id)).delete_all
    @drena.delete
  end

  test "five simultaneous joins of a teacher with two schools: exactly one is attached" do
    gate = Queue.new
    threads = @targets.map do |school|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection do
          Repositories::School::SchoolRepository.new.attach_teacher_within_cap(teacher_id: @teacher.id, school_id: school.id,
                                                                             cap: 3, at: Time.current)
        end
      end
    end
    ATTEMPTS.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal 3, Orm::TeacherSchool.where(teacher_id: @teacher.id).count
  end
end
