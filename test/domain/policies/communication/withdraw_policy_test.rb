require "test_helper"

module Policies
  module Communication
    # ADR-0078 §4.2 and §6: the team withdraws any announcement of another author; a direction, those of the teachers
    # of its school. Anyone else is answered as if the announcement did not exist (not_found); an archived or withdrawn
    # one is frozen (conflict). Without database.
    class WithdrawPolicyTest < ActiveSupport::TestCase
      LAURIERS = 7
      BOUAKE = 8
      KOUASSI = 40

      def actor(role, user_id: 1, school_id: LAURIERS)
        Entities::Identity::Actor.new(user_id:, role:, team_role: (role == :team ? "admin" : nil), school_id:)
      end

      def announcement(author_id: KOUASSI, school_id: LAURIERS, status: "published")
        Entities::Communication::Message.new(id: 3, public_id: "fiches", author_id:, title: "Nouvelles fiches", body: "En ligne.",
                                             audience: "classrooms", school_id:, classroom_ids: [ 4 ], illustration: "sheets", status:)
      end

      def call(actor, message = announcement, author_role: :teacher)
        WithdrawPolicy.new.call(actor:, message:, author_role:)
      end

      test "AN-16 — the team withdraws the announcement of a teacher, of a direction, of another member of the team" do
        assert call(actor(:team, school_id: nil)).success?
        assert call(actor(:team, school_id: nil), announcement(author_id: 50, school_id: BOUAKE), author_role: :school_admin).success?
        assert call(actor(:team, school_id: nil), announcement(author_id: 60, school_id: nil), author_role: :team).success?
      end

      test "AN-16 — only archived and withdrawn are frozen: a scheduled announcement or a draft may be withdrawn" do
        assert call(actor(:team, school_id: nil), announcement(status: "scheduled")).success?
        assert call(actor(:school_admin), announcement(status: "draft")).success?
      end

      test "AN-17 — the direction withdraws the announcement of a teacher of its school" do
        assert call(actor(:school_admin)).success?
      end

      test "AN-17 — the direction of another school receives not_found" do
        assert_equal :not_found, call(actor(:school_admin, school_id: BOUAKE)).code
      end

      test "AN-17 — the direction receives not_found for an announcement of the team and for one of another direction" do
        assert_equal :not_found, call(actor(:school_admin), announcement(author_id: 60, school_id: nil), author_role: :team).code
        assert_equal :not_found, call(actor(:school_admin), announcement(author_id: 50), author_role: :school_admin).code
      end

      test "AN-17 — a teacher receives not_found, for a colleague's announcement as for his own" do
        assert_equal :not_found, call(actor(:teacher, user_id: 41)).code
        assert_equal :not_found, call(actor(:teacher, user_id: KOUASSI)).code
      end

      test "a student receives not_found" do
        assert_equal :not_found, call(actor(:student)).code
      end

      test "the team receives not_found for its own announcement: withdrawing is not managing" do
        assert_equal :not_found, call(actor(:team, user_id: 60, school_id: nil), announcement(author_id: 60, school_id: nil),
                                      author_role: :team).code
      end

      test "a visitor and an unknown announcement receive not_found" do
        assert_equal :not_found, call(nil).code
        assert_equal :not_found, call(actor(:team, school_id: nil), nil).code
      end

      test "AN-16 — archived or withdrawn, the announcement is frozen: conflict" do
        %w[archived withdrawn].each do |status|
          assert_equal :conflict, call(actor(:team, school_id: nil), announcement(status:)).code, status
          assert_equal :conflict, call(actor(:school_admin), announcement(status:)).code, status
        end
      end

      test "a frozen announcement outside the right stays not_found" do
        assert_equal :not_found, call(actor(:school_admin, school_id: BOUAKE), announcement(status: "withdrawn")).code
      end
    end
  end
end
