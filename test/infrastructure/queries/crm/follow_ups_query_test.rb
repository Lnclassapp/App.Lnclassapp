require "test_helper"

# CA-13, CA-14: the open follow-ups of a school, « Mes relances » (échues d'abord) and the orphans (destinataire indisponible).
module Queries
  module Crm
    class FollowUpsQueryTest < ActiveSupport::TestCase
      setup do
        @drena = create_drena(name: "Abidjan 1")
        @school = create_school(drena: @drena, name: "Lycée Classique")
        @me = create_team_member(team_role: "field")
        @other = create_team_member(team_role: "admin")
        @query = FollowUpsQuery.new
      end

      def schedule(assignee: @me, school: @school, due_on: Date.new(2026, 11, 6), status: "open", reason: "Rappeler")
        done = status == "done" ? { done_at: Time.current, done_by: assignee } : {}
        Orm::CrmFollowUp.create!(school:, assignee:, due_on:, reason:, status:, created_by: @me, **done)
      end

      test "for_school lists the open follow-ups of the school by due date, with recipient and availability" do
        later = schedule(due_on: Date.new(2026, 11, 9))
        soon = schedule(assignee: @other, due_on: Date.new(2026, 11, 6))
        schedule(status: "done")
        schedule(school: create_school)

        rows = @query.for_school(school_id: @school.id)

        assert_equal [ soon.public_id, later.public_id ], rows.map(&:public_id)
        assert_equal [ @other.public_id, true ], [ rows.first.assignee_public_id, rows.first.assignee_available ]
        assert_equal [ "Lycée Classique", "Abidjan 1" ], [ rows.first.school_name, rows.first.drena_name ]
      end

      test "mine lists only my open follow-ups, the overdue ones first" do
        fresh = schedule(due_on: Date.new(2026, 11, 12))
        overdue = schedule(due_on: Date.new(2026, 11, 2))
        schedule(assignee: @other)
        schedule(status: "done")

        page = @query.mine(user_id: @me.id, page: 1)

        assert_equal [ overdue.public_id, fresh.public_id ], page.rows.map(&:public_id)
        assert_equal [ 2, 1, 1 ], [ page.total_count, page.page, page.pages ]
      end

      test "mine pages by 25 and clamps a wild page" do
        26.times { |i| schedule(due_on: Date.new(2026, 11, 6) + i) }

        assert_equal [ 25, 2 ], [ @query.mine(user_id: @me.id, page: 1).rows.size, @query.mine(user_id: @me.id, page: 1).pages ]
        assert_equal 1, @query.mine(user_id: @me.id, page: 2).rows.size
        assert_equal 2, @query.mine(user_id: @me.id, page: 99).page
        assert_equal 1, @query.mine(user_id: @me.id, page: %w[x]).page
      end

      test "orphans are the open follow-ups whose recipient is anonymized or no longer admin or field" do
        anonymized = create_team_member(team_role: "field", anonymized_at: Time.current)
        demoted = create_team_member(team_role: "content")
        orphan_a = schedule(assignee: anonymized)
        orphan_b = schedule(assignee: demoted, due_on: Date.new(2026, 11, 8))
        schedule(assignee: @other)
        schedule(assignee: anonymized, status: "done")

        page = @query.orphans(page: 1)

        assert_equal [ orphan_a.public_id, orphan_b.public_id ], page.rows.map(&:public_id)
        assert_equal [ false, false ], page.rows.map(&:assignee_available)
      end

      test "a row carries the owner of the school, nil without an account" do
        record = schedule
        assert_nil @query.find(public_id: record.public_id).owner_id

        Orm::CrmAccount.create!(school: @school, owner: @other, stage_changed_at: Time.current)

        assert_equal @other.id, @query.find(public_id: record.public_id).owner_id
        assert_nil @query.find(public_id: "unknown-public")
        record.update!(status: "done", done_at: Time.current, done_by: @me)
        assert_nil @query.find(public_id: record.public_id)
      end

      test "owner_id is the owner of the school, nil without an account or without an owner" do
        assert_nil @query.owner_id(school_id: @school.id)

        account = Orm::CrmAccount.create!(school: @school, stage_changed_at: Time.current)
        assert_nil @query.owner_id(school_id: @school.id)

        account.update!(owner: @other)
        assert_equal @other.id, @query.owner_id(school_id: @school.id)
      end

      test "mine costs the same number of queries whatever the number of schools" do
        schedule
        count = ->(&block) { n = 0; sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| n += 1 unless p[:name] == "SCHEMA" }; block.call; ActiveSupport::Notifications.unsubscribe(sub); n }
        one = count.call { @query.mine(user_id: @me.id, page: 1) }
        5.times { schedule(school: create_school) }

        assert_equal one, count.call { @query.mine(user_id: @me.id, page: 1) }
      end
    end
  end
end
