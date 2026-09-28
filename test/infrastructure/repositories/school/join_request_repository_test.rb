require "test_helper"

module Repositories
  module School
    # CP-11 to CP-13 (ADR-0063): the requests of teachers who signed up without code, and their decision, which attaches
    # the teacher in the same write.
    class JoinRequestRepositoryTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)

      setup do
        @repository = JoinRequestRepository.new
        @school = create_school
        @teacher = create_teacher(school: nil, first_name: "Awa", last_name: "Koné")
        @team = create_team_member
      end

      test "creates one pending request per teacher, read back by its public id with the teacher's name" do
        created = @repository.create(teacher_id: @teacher.id, school_id: @school.id, at: NOW, max_pending: 5)

        assert created.success?
        request = @repository.find_by_public_id(public_id: created.value.public_id)
        assert_equal [ @teacher.id, @school.id, "pending", "Awa Koné" ], [ request.teacher_id, request.school_id, request.status, request.teacher_name ]
        assert_equal 14, request.public_id.size
        assert_equal :conflict, @repository.create(teacher_id: @teacher.id, school_id: create_school.id, at: NOW, max_pending: 5).code
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "B2: refuses a request beyond the cap of pending requests of the school; decided ones and other schools do not count" do
        2.times { create_join_request(school: @school) }
        create_join_request(school: @school, status: "rejected")
        create_join_request

        refused = @repository.create(teacher_id: @teacher.id, school_id: @school.id, at: NOW, max_pending: 2)
        assert_equal [ :invalid, { base: [ :too_many_pending ] } ], [ refused.code, refused.errors ]
        assert_not Orm::SchoolJoinRequest.exists?(teacher: @teacher)
        assert @repository.create(teacher_id: @teacher.id, school_id: @school.id, at: NOW, max_pending: 3).success?
      end

      test "approve decides the request and attaches the teacher as primary, once" do
        request = create_join_request(school: @school, teacher: @teacher)

        assert @repository.approve(id: request.id, decided_by_id: @team.id, via: "team", at: NOW).success?
        assert_equal [ "approved", NOW, @team.id, "team" ], request.reload.values_at(:status, :decided_at, :decided_by_id, :decided_via)
        assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id, :primary)

        second = @repository.approve(id: request.id, decided_by_id: @team.id, via: "sponsor", at: NOW)
        assert_equal [ :conflict, { base: [ :already_decided ] } ], [ second.code, second.errors ]
        assert_equal 1, Orm::TeacherSchool.where(teacher: @teacher).count
      end

      test "approve a teacher who meanwhile got a primary school: conflict, the request stays pending" do
        request = create_join_request(school: @school, teacher: @teacher)
        Orm::TeacherSchool.create!(teacher: @teacher, school: create_school, primary: true)

        assert_equal :conflict, @repository.approve(id: request.id, decided_by_id: @team.id, via: "team", at: NOW).code
        assert_equal "pending", request.reload.status
      end

      test "reject decides the request without attaching anyone, once" do
        request = create_join_request(school: @school, teacher: @teacher)

        assert @repository.reject(id: request.id, decided_by_id: @team.id, at: NOW).success?
        assert_equal [ "rejected", "team" ], request.reload.values_at(:status, :decided_via)
        assert_equal 0, Orm::TeacherSchool.where(teacher: @teacher).count
        assert_equal :conflict, @repository.reject(id: request.id, decided_by_id: @team.id, at: NOW).code
      end

      test "pending_for reads the pending request of a teacher, and nothing once it is decided (ADR-0066 §4.5)" do
        created = @repository.create(teacher_id: @teacher.id, school_id: @school.id, at: NOW, max_pending: 5).value

        assert_equal created, @repository.pending_for(teacher_id: @teacher.id)
        assert_nil @repository.pending_for(teacher_id: create_teacher(school: nil).id)

        @repository.reject(id: created.id, decided_by_id: @team.id, at: NOW)
        assert_nil @repository.pending_for(teacher_id: @teacher.id)
      end
    end
  end
end
