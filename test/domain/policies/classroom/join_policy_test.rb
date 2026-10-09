require "test_helper"

module Policies
  module Classroom
    # ADR-0085 §4.3: a visitor or a student enters an active classroom under its ceiling; a student removed from it is
    # refused, unless the entry comes from the classroom link. There is no classroom code to check any more (Lot F).
    class JoinPolicyTest < ActiveSupport::TestCase
      def classroom(**overrides)
        Entities::Classroom::Classroom.new(name: "3ème 1", active_students_count: 10, **overrides)
      end

      def call(actor: nil, via_link: false, removed: false, **overrides)
        JoinPolicy.new.call(actor:, classroom: classroom(**overrides), via_link:, removed:)
      end

      test "IL-01, IL-08: a visitor or a student enters an active classroom, by the standard way or by the link" do
        assert call.success?
        assert call(via_link: true).success?
        assert call(actor: Entities::Identity::Actor.new(user_id: 1, role: :student)).success?
      end

      test "IL-03: no teacher is needed, nor any code" do
        assert call(teacher_ids: []).success?
      end

      test "a teacher, the direction or the team are refused" do
        %i[teacher school_admin team].each do |role|
          result = call(actor: Entities::Identity::Actor.new(user_id: 1, role:))

          assert_equal :forbidden, result.code
          assert_empty result.errors
        end
      end

      test "each refusal names its reason" do
        assert_equal [ :classroom_archived ], call(status: "archived").errors[:base]
        assert_equal [ :classroom_full ], call(active_students_count: 80).errors[:base]
        assert_equal [ :removed_from_classroom ], call(removed: true).errors[:base]
      end

      test "IL-15, IL-16: a removed student is refused by the standard way, let in by the link" do
        assert call(removed: true, via_link: true).success?
        assert_equal :forbidden, call(removed: true).code
      end

      test "IL-05: a full classroom refuses both ways; an archived one too" do
        [ true, false ].each do |via_link|
          assert_equal [ :classroom_full ], call(via_link:, active_students_count: 80).errors[:base]
          assert_equal [ :classroom_archived ], call(via_link:, status: "archived").errors[:base]
        end
      end

      test "IL-02: no classroom code is accepted any more" do
        assert_raises(ArgumentError) { JoinPolicy.new.call(actor: nil, classroom: classroom, code: "abc23") }
      end
    end
  end
end
