require "test_helper"

# ADR-0071 §4.4, §4.5 : un retrait s'inscrit, se lit ouvert, et se ferme à la réintégration.
module Repositories
  module School
    class TeacherDepartureRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = TeacherDepartureRepository.new
        @school = create_school
        @teacher = create_teacher(school: nil)
        @admin = create_school_admin(school: @school)
        @at = Time.zone.parse("2026-10-01 09:00")
      end

      test "record inscrit un départ ouvert et le rend en entité" do
        departure = @repository.record(teacher_id: @teacher.id, school_id: @school.id, detached_by_id: @admin.id, at: @at)

        assert_kind_of Entities::School::TeacherDeparture, departure
        assert_equal [ @teacher.id, @school.id, @admin.id, @at ],
                     [ departure.teacher_id, departure.school_id, departure.detached_by_id, departure.detached_at ]
        assert_predicate departure, :open?
        assert Orm::TeacherSchoolDeparture.exists?(departure.id)
      end

      test "open_for lit le départ ouvert de ce couple, et rien pour un autre établissement ou un départ clos" do
        create_teacher_departure(teacher: @teacher, school: @school, detached_by: @admin, reinstated: true)
        open = create_teacher_departure(teacher: @teacher, school: @school, detached_by: @admin)
        other = create_school

        assert_equal open.id, @repository.open_for(teacher_id: @teacher.id, school_id: @school.id).id
        assert_nil @repository.open_for(teacher_id: @teacher.id, school_id: other.id)
        assert_nil @repository.open_for(teacher_id: create_teacher(school: nil).id, school_id: @school.id)
      end

      test "close pose la réintégration, et le couple n'a plus de départ ouvert" do
        departure = @repository.record(teacher_id: @teacher.id, school_id: @school.id, detached_by_id: @admin.id, at: @at)
        later = @at + 1.day

        assert_equal true, @repository.close(id: departure.id, reinstated_by_id: @admin.id, at: later)
        assert_nil @repository.open_for(teacher_id: @teacher.id, school_id: @school.id)
        record = Orm::TeacherSchoolDeparture.find(departure.id)
        assert_equal [ @admin.id, later ], [ record.reinstated_by_id, record.reinstated_at ]
      end

      test "close ne rouvre ni ne réécrit un départ déjà clos" do
        closed = create_teacher_departure(teacher: @teacher, school: @school, detached_by: @admin, reinstated: true)
        reinstated_at = closed.reload.reinstated_at

        assert_equal true, @repository.close(id: closed.id, reinstated_by_id: create_school_admin(school: @school).id, at: @at)
        assert_equal [ @admin.id, reinstated_at ], [ closed.reload.reinstated_by_id, closed.reinstated_at ]
      end
    end
  end
end
