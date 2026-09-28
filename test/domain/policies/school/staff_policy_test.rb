require "test_helper"

module Policies
  module School
    # ADR-0066 §4.3: one gesture policy for the direction, bounded to the actor's active school; the team has every
    # gesture on every school. Every cell of the table is checked, the empty ones included.
    class StaffPolicyTest < ActiveSupport::TestCase
      Actor = Entities::Identity::Actor
      TABLE = {
        read: %w[principal censor educator secretary],
        add_classroom: %w[principal censor educator secretary],
        place_student: %w[principal censor educator secretary],
        invite_staff: %w[principal censor],
        invite_principal: [],
        regenerate_code: %w[principal censor],
        detach_teacher: %w[principal censor],
        reinstate_teacher: %w[principal censor],
        detach_staff: %w[principal censor]
      }.freeze
      POSITIONS = %w[principal censor educator secretary].freeze

      setup do
        @school = Entities::School::School.new(id: 31, status: "active")
        @other = Entities::School::School.new(id: 32, status: "active")
      end

      def call(actor, gesture, school: @school) = StaffPolicy.new.call(actor:, school:, gesture:)
      def member(position, school_id: 31) = Actor.new(user_id: 7, role: :school_admin, school_id:, position:)

      test "the table covers every gesture of StaffPosition" do
        assert_equal Entities::School::StaffPosition::ALL_GESTURES.sort, TABLE.keys.sort
      end

      test "each position of the school has exactly the gestures of its cells, and the reason of a refusal is the position" do
        TABLE.each do |gesture, allowed|
          POSITIONS.each do |position|
            result = call(member(position), gesture)

            if allowed.include?(position)
              assert result.success?, "#{position} #{gesture}"
            else
              assert_equal [ :forbidden, { base: [ :position ] } ], [ result.code, result.errors ], "#{position} #{gesture}"
            end
          end
        end
      end

      test "the team has every gesture, on any school, whatever its status" do
        team = Actor.new(user_id: 1, role: :team, team_role: "field")

        TABLE.each_key do |gesture|
          [ @school, @other, Entities::School::School.new(id: 33, status: "inactive"), nil ].each do |school|
            assert call(team, gesture, school:).success?, "#{gesture} #{school&.id}"
          end
        end
      end

      test "a member of another school is refused every gesture, without saying why" do
        TABLE.each_key do |gesture|
          POSITIONS.each do |position|
            result = call(member(position), gesture, school: @other)

            assert_equal [ :forbidden, {} ], [ result.code, result.errors ], "#{position} #{gesture}"
          end
        end
      end

      test "an inactive or draft school refuses its own direction" do
        %w[inactive draft].each do |status|
          school = Entities::School::School.new(id: 31, status:)

          TABLE.each_key { assert_equal :forbidden, call(member("principal"), it, school:).code, "#{status} #{it}" }
        end
      end

      test "a school_admin without position or without school, a missing school, other roles and a visitor are refused" do
        actors = [ member(nil), member("principal", school_id: nil), Actor.new(user_id: 2, role: :teacher, school_id: 31),
                   Actor.new(user_id: 3, role: :student, school_id: 31), nil ]

        TABLE.each_key do |gesture|
          actors.each { assert_equal :forbidden, call(it, gesture).code, "#{it.inspect} #{gesture}" }
          assert_equal :forbidden, call(member("principal"), gesture, school: nil).code
        end
      end

      test "an unknown gesture raises, for the team, a member and a visitor" do
        [ Actor.new(user_id: 1, role: :team, team_role: "admin"), member("principal"), nil ].each do |actor|
          assert_raises(ArgumentError) { call(actor, :delete_school) }
        end
      end
    end
  end
end
