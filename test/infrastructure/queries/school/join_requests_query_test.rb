require "test_helper"

module Queries
  module School
    # CP-11 to CP-13 (ADR-0063, UDR-0050): the pending requests, as the team reads them on the school page (with the
    # number), as an active colleague reads them on the home (without the number), and the state the requester reads.
    class JoinRequestsQueryTest < ActiveSupport::TestCase
      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan")
        @svt = create_material(name: "SVT", category: "science")
        @awa = create_teacher(school: nil, material: @svt, first_name: "Awa", last_name: "Koné", contact: "0501020304")
        @request = create_join_request(school: @school, teacher: @awa, created_at: 2.days.ago)
        @newer = create_join_request(school: @school, created_at: 1.day.ago)
        create_join_request(school: @school, status: "rejected")
        create_join_request
      end

      test "for the team: the pending requests of the school, oldest first, with the number and the subject" do
        rows = JoinRequestsQuery.new.for_school(school_public_id: @school.public_id)

        assert_equal [ @request.public_id, @newer.public_id ], rows.map(&:public_id)
        assert_equal [ "Awa Koné", "0501020304", "SVT", "science" ], rows.first.to_h.values_at(:name, :contact, :material_name, :material_category)
      end

      test "for an active colleague: the same list without the number, and the school's name" do
        colleague = create_teacher(school: @school)

        pending = JoinRequestsQuery.new.for_colleague(teacher_id: colleague.id)

        assert_equal "Lycée Classique d'Abidjan", pending.school_name
        assert_equal [ @request.public_id, @newer.public_id ], pending.requests.map(&:public_id)
        assert_not_respond_to pending.requests.first, :contact
      end

      test "a colleague of another school, or without pending request, gets nil" do
        assert_nil JoinRequestsQuery.new.for_colleague(teacher_id: create_teacher.id)
        assert_nil JoinRequestsQuery.new.for_colleague(teacher_id: create_teacher(school: nil).id)
      end

      test "for the requester: the school and the state of the request" do
        assert_equal [ "Lycée Classique d'Abidjan", "pending" ], JoinRequestsQuery.new.status_for(teacher_id: @awa.id).to_h.values
        assert_nil JoinRequestsQuery.new.status_for(teacher_id: create_teacher.id)
      end
    end
  end
end
