require "test_helper"

module Policies
  module Communication
    # ADR-0069 §4.4 and §6: the image or the audio of a message is served to its readers (the reading rule), to its author,
    # to the team, and to the direction that may withdraw it; anyone else learns nothing of it (not_found). Without database.
    class ReadFilePolicyTest < ActiveSupport::TestCase
      SCHOOL = 7
      OTHER_SCHOOL = 8

      def actor(role, user_id: 1, school_id: SCHOOL)
        Entities::Identity::Actor.new(user_id:, role:, team_role: (role == :team ? "admin" : nil), school_id:)
      end

      def announcement(author_id: 99, school_id: SCHOOL, status: "published")
        Entities::Communication::Message.new(id: 3, public_id: "msg", author_id:, title: "Nouvelles fiches", body: "En ligne.",
                                             audience: "classrooms", school_id:, classroom_ids: [ 4 ], illustration: "sheets", status:)
      end

      def call(actor, message = announcement, readable: false, author_role: :teacher)
        ReadFilePolicy.new.call(actor:, message:, readable:, author_role:)
      end

      test "AN-09 — a reader of the message receives its files" do
        assert call(actor(:student), readable: true).success?
        assert call(actor(:teacher), readable: true, author_role: :team).success?
      end

      test "AN-09, AN-19 — its author receives them in any state, the team for any message" do
        assert call(actor(:teacher, user_id: 99), announcement(status: "draft")).success?
        assert call(actor(:teacher, user_id: 99), announcement(status: "archived")).success?
        assert call(actor(:team, school_id: nil), announcement(status: "withdrawn"), author_role: :school_admin).success?
      end

      test "the direction receives the files of a teacher of its school, the one it may withdraw" do
        assert call(actor(:school_admin)).success?
      end

      test "AN-09 — a student outside the audience, or once it is unreadable, gets not_found" do
        assert_equal :not_found, call(actor(:student)).code
      end

      test "another teacher, a direction of another school, or a direction on the team's or a colleague's message: not_found" do
        assert_equal :not_found, call(actor(:teacher, user_id: 2)).code
        assert_equal :not_found, call(actor(:school_admin, school_id: OTHER_SCHOOL)).code
        assert_equal :not_found, call(actor(:school_admin), author_role: :team).code
        assert_equal :not_found, call(actor(:school_admin), author_role: :school_admin).code
      end

      test "a visitor gets not_found" do
        assert_equal :not_found, call(nil, readable: true).code
      end
    end
  end
end
