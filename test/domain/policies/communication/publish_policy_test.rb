require "test_helper"

module Policies
  module Communication
    # ADR-0078 §4.2 and §6: who writes an announcement, and for whom. One refusal per actor and per scope; the values
    # come from the request, forged or not, and only the policy decides.
    class PublishPolicyTest < ActiveSupport::TestCase
      LAURIERS = 10
      BOUAKE = 20

      def actor(role, school_id: nil, user_id: 1) = Entities::Identity::Actor.new(user_id:, role:, school_id:)
      def team = actor(:team)
      def direction(school_id: LAURIERS) = actor(:school_admin, school_id:)
      def teacher(school_id: LAURIERS) = actor(:teacher, school_id:)

      def call(actor, scope: "school", school_id: LAURIERS, audience: "students", classroom_ids: [], teachable_classroom_ids: [])
        PublishPolicy.new.call(actor:, scope:, school_id:, audience:, classroom_ids:, teachable_classroom_ids:)
      end

      test "a visitor and a student write nothing" do
        assert_equal :forbidden, call(nil).code
        assert_equal :forbidden, call(actor(:student, school_id: LAURIERS)).code
      end

      test "AN-01, AN-02 — the team writes nationally or for one school, to everyone or to one role" do
        %w[all students teachers school_admins].each do |audience|
          assert call(team, scope: "national", school_id: nil, audience:).success?, audience
          assert call(team, scope: "school", school_id: BOUAKE, audience:).success?, audience
        end
      end

      test "the team is refused a national scope with a school, a school scope without one, or an unknown scope" do
        assert_equal :forbidden, call(team, scope: "national", school_id: LAURIERS).code
        assert_equal :forbidden, call(team, scope: "school", school_id: nil).code
        assert_equal :forbidden, call(team, scope: "world", school_id: nil).code
      end

      test "the team targets no classroom" do
        assert_equal :forbidden, call(team, audience: "classrooms").code
        assert_equal :forbidden, call(team, classroom_ids: [ 3 ]).code
      end

      test "AN-03 — the direction writes for its own school, to students, teachers or directions" do
        %w[students teachers school_admins].each { assert call(direction, audience: it).success?, it }
      end

      test "AN-04 — the direction is refused another school, the national scope and the audience « Tous »" do
        assert_equal :forbidden, call(direction, school_id: BOUAKE).code
        assert_equal :forbidden, call(direction, scope: "national", school_id: nil).code
        assert_equal :forbidden, call(direction, scope: "national").code
        assert_equal :forbidden, call(direction, audience: "all").code
      end

      test "a direction without a school, or targeting classrooms, is refused" do
        assert_equal :forbidden, call(direction(school_id: nil), school_id: nil).code
        assert_equal :forbidden, call(direction, audience: "classrooms").code
        assert_equal :forbidden, call(direction, classroom_ids: [ 3 ]).code
      end

      test "AN-05 — the teacher writes to classrooms he teaches, in his school" do
        assert call(teacher, audience: "classrooms", classroom_ids: [ 3, 4 ], teachable_classroom_ids: [ 3, 4, 5 ]).success?
      end

      test "AN-06 — the teacher is refused a classroom he does not teach" do
        assert_equal :forbidden, call(teacher, audience: "classrooms", classroom_ids: [ 3, 6 ], teachable_classroom_ids: [ 3 ]).code
        assert_equal :forbidden, call(teacher, audience: "classrooms", classroom_ids: [ nil ], teachable_classroom_ids: [ 3 ]).code
      end

      test "AN-06 — without any classroom, the teacher is asked to choose one (a form error, not a refusal)" do
        result = call(teacher, audience: "classrooms", classroom_ids: [], teachable_classroom_ids: [ 3 ])

        assert_equal :invalid, result.code
        assert_equal({ classroom_public_ids: [ :no_classroom ] }, result.errors)
      end

      test "the teacher targets no role, no other school and nothing national" do
        assert_equal :forbidden, call(teacher, audience: "students", classroom_ids: [ 3 ], teachable_classroom_ids: [ 3 ]).code
        assert_equal :forbidden, call(teacher, audience: "classrooms", school_id: BOUAKE, classroom_ids: [ 3 ],
                                               teachable_classroom_ids: [ 3 ]).code
        assert_equal :forbidden, call(teacher, scope: "national", school_id: nil, audience: "classrooms", classroom_ids: [ 3 ],
                                               teachable_classroom_ids: [ 3 ]).code
        assert_equal :forbidden, call(teacher, scope: "national", audience: "classrooms", classroom_ids: [ 3 ],
                                               teachable_classroom_ids: [ 3 ]).code
        assert_equal :forbidden, call(teacher(school_id: nil), school_id: nil, audience: "classrooms", classroom_ids: [ 3 ],
                                                                teachable_classroom_ids: [ 3 ]).code
      end
    end
  end
end
