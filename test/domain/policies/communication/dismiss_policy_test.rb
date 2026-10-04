require "test_helper"

module Policies
  module Communication
    # ADR-0078 §4.2: a student hides a message they read, unless it is official (written by a direction). Anyone else, or
    # an unreadable message, is refused. Without database.
    class DismissPolicyTest < ActiveSupport::TestCase
      def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:, team_role: (role == :team ? "admin" : nil))
      def call(actor, readable: true, author_role: :teacher) = DismissPolicy.new.call(actor:, readable:, author_role:)

      test "AN-12 — a student hides a readable message of a teacher or of the team" do
        assert call(actor(:student)).success?
        assert call(actor(:student), author_role: :team).success?
      end

      test "AN-13 — an official message cannot be hidden" do
        assert_equal :forbidden, call(actor(:student), author_role: :school_admin).code
      end

      test "a message the student does not read cannot be hidden" do
        assert_equal :forbidden, call(actor(:student), readable: false).code
      end

      test "a teacher, a direction, the team and a visitor hide nothing" do
        [ actor(:teacher), actor(:school_admin), actor(:team), nil ].each do |actor|
          assert_equal :forbidden, call(actor).code, actor&.role.inspect
        end
      end
    end
  end
end
