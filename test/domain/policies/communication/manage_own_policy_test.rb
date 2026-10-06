require "test_helper"

module Policies
  module Communication
    # ADR-0078 §4.2 and §6: only its author modifies, schedules or archives an announcement; anyone else, the team and
    # the direction included, is answered as if it did not exist. Archived or withdrawn, it is frozen.
    class ManageOwnPolicyTest < ActiveSupport::TestCase
      AUTHOR = 7

      def actor(role, user_id: AUTHOR) = Entities::Identity::Actor.new(user_id:, role:, school_id: 10)

      def announcement(status: "published")
        Entities::Communication::Message.new(id: 1, author_id: AUTHOR, title: "Devoirs communs", body: "Lundi.",
                                             audience: "students", illustration: "info", status:, school_id: 10)
      end

      def call(actor, message = announcement) = ManageOwnPolicy.new.call(actor:, message:)

      test "its author manages a draft, a scheduled and a published announcement" do
        %w[draft scheduled published].each { assert call(actor(:school_admin), announcement(status: it)).success?, it }
      end

      test "AN-15 — another direction, the team and a teacher receive not_found" do
        %i[school_admin team teacher].each { assert_equal :not_found, call(actor(it, user_id: 99)).code, it }
      end

      test "a visitor and an unknown announcement receive not_found" do
        assert_equal :not_found, call(nil).code
        assert_equal :not_found, call(actor(:teacher), nil).code
      end

      test "AN-19 — archived or withdrawn, the announcement is frozen for its author" do
        %w[archived withdrawn].each { assert_equal :conflict, call(actor(:teacher), announcement(status: it)).code, it }
      end

      test "a frozen announcement of someone else stays not_found" do
        assert_equal :not_found, call(actor(:team, user_id: 99), announcement(status: "archived")).code
      end
    end
  end
end
