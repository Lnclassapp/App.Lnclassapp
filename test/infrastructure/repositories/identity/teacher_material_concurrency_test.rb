require "test_helper"

# ADR-0103 §4.4: two simultaneous « Mes matières » of a teacher serialize on his attachment row (teacher_schools): the
# list of a school never holds more than three subjects. Outside any test transaction: threads need their own.
class TeacherMaterialConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @drena = create_drena
    @school = create_school(drena: @drena)
    @materials = Array.new(6) { create_material }
    @teacher = create_teacher(school: @school, material: @materials.first)
    Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).delete_all
  end

  teardown do
    Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).delete_all
    Orm::TeacherSchool.where(teacher_id: @teacher.id).delete_all
    Orm::TeacherProfile.where(user_id: @teacher.id).delete_all
    Orm::User.where(id: @teacher.id).delete_all
    Orm::Material.where(id: @materials.map(&:id)).delete_all
    Orm::School.where(id: @school.id).delete_all
    @drena.delete
  end

  ROUNDS = 20

  test "two simultaneous disjoint lists of three, many times: three rows at most, the list of one of them" do
    lists = [ @materials.first(3).map(&:id), @materials.last(3).map(&:id) ]
    ROUNDS.times do
      Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id).delete_all
      gate = Queue.new
      threads = lists.map do |ids|
        Thread.new do
          gate.pop
          ActiveRecord::Base.connection_pool.with_connection do
            ActiveRecord::Base.transaction do
              Repositories::Identity::TeacherMaterialRepository.new.replace(teacher_id: @teacher.id, school_id: @school.id,
                                                                            material_ids: ids, at: Time.current)
            end
          end
        end
      end
      lists.size.times { gate << true }

      assert threads.map(&:value).all?
      stored = Orm::TeacherSchoolMaterial.where(teacher_id: @teacher.id, school_id: @school.id).pluck(:material_id)
      assert_includes lists, stored.sort, "au plus trois lignes, celles d'une seule des deux listes"
    end
  end
end
