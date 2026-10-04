require "test_helper"

# ADR-0077, UDR-0070 : le bloc « Direction », le bandeau d'arrivée et les directions retirées lisent school_staffs.
module Queries
  module School
    class SchoolStaffQueryTest < ActiveSupport::TestCase
      setup do
        @query = SchoolStaffQuery.new
        @school = create_school
        @now = Time.zone.parse("2026-10-04 12:00")
      end

      test "active_for lists the active accounts of the school, oldest first, with their arrival" do
        kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_at: @now - 10.days)
        aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Kouassi", joined_via: "code", joined_at: @now - 2.days)
        create_school_admin(school: @school, archived_at: @now)
        create_school_admin(school: create_school)

        rows = @query.active_for(school_id: @school.id)

        assert_equal [ kofi.public_id, aya.public_id ], rows.map(&:public_id)
        assert_equal [ kofi.id, "Kofi Yao", "invitation", @now - 10.days ], rows.first.then { [ it.user_id, it.name, it.joined_via, it.joined_at ] }
        assert_equal "code", rows.last.joined_via
      end

      test "by_code_count counts the active accounts by code only" do
        2.times { create_school_admin(school: @school, joined_via: "code") }
        create_school_admin(school: @school, joined_via: "code", archived_at: @now)
        create_school_admin(school: @school)

        assert_equal 2, @query.by_code_count(school_id: @school.id)
      end

      test "recent_arrivals reads the arrivals since a date, except the reader, newest first, three at most" do
        reader = create_school_admin(school: @school, joined_at: @now - 1.day)
        arrivals = Array.new(4) { |index| create_school_admin(school: @school, joined_at: @now - (index + 2).hours) }
        create_school_admin(school: @school, joined_at: @now - 8.days)
        create_school_admin(school: @school, joined_at: @now - 1.hour, archived_at: @now)

        rows = @query.recent_arrivals(school_id: @school.id, since: @now - 7.days, except_user_id: reader.id)

        assert_equal arrivals.first(3).map(&:public_id), rows.map(&:public_id)
      end

      test "archived lists the archived accounts with school, author and deletion date, newest first" do
        author = create_team_member(first_name: "Awa", last_name: "Traoré")
        old = create_school_admin(school: @school, first_name: "Old", last_name: "One", archived_at: @now - 2.days, archived_by: author)
        recent = create_school_admin(school: create_school, archived_at: @now, archived_by: author)
        create_school_admin(school: @school)

        assert_equal [ recent.public_id, old.public_id ], @query.archived.map(&:public_id)
        row = @query.archived(school_id: @school.id).sole
        assert_equal [ "Old One", @school.public_id, @school.name, "Awa Traoré", "invitation" ],
                     [ row.name, row.school_public_id, row.school_name, row.archived_by_name, row.joined_via ]
        assert_equal @now - 2.days + 30.days, row.deletion_due_at
      end
    end
  end
end
