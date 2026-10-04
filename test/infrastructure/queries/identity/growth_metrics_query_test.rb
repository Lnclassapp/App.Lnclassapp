require "test_helper"

module Queries
  module Identity
    # CP-16, CP-17 (ADR-0063): the growth indicators of a period, read from the tables in a bounded number of queries.
    class GrowthMetricsQueryTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 9, 28, 12)
      FROM = NOW - 30.days

      def metrics = GrowthMetricsQuery.new.call(from: FROM, to: NOW)

      def count_queries(&)
        count = 0
        ActiveSupport::Notifications.subscribed(->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }, "sql.active_record", &)
        count
      end

      setup do
        @school = create_school(name: "Lycée Classique d'Abidjan", drena: create_drena(name: "Abidjan 1"))
        @old = create_teacher(school: @school, first_name: "Ancien", created_at: NOW - 60.days)
        @aya = create_teacher(school: @school, first_name: "Aya", last_name: "Koné", created_at: NOW - 20.days)
        @koffi = create_teacher(school: @school, first_name: "Koffi", created_at: NOW - 17.days)
        @awa = create_teacher(school: @school, first_name: "Awa", created_at: NOW - 10.days)
        create_referral(referrer: @aya, referee: @koffi, created_at: NOW - 17.days)
        create_referral(referrer: @aya, referee: @awa, created_at: NOW - 10.days)
        create_referral(referrer: @old, referee: @aya, created_at: NOW - 20.days)
        4.times { create_referral_share(user: @aya, created_at: NOW - 18.days) }
        create_referral_share(user: @old, created_at: NOW - 19.days)
        create_referral_share(user: @old, created_at: NOW - 40.days)
        classroom = create_classroom(school: @school)
        3.times { create_student(classroom:) }
        Orm::ClassroomStudent.update_all(joined_at: NOW - 5.days)
        create_join_request(school: @school, teacher: create_teacher(school: nil, created_at: NOW - 90.days), created_at: NOW - 3.days)
      end

      test "shares, sign-ups and referred sign-ups of the period, and the conversion per share" do
        row = metrics

        assert_equal [ 5, 3, 3 ], [ row.shares, row.teacher_signups, row.referred_signups ]
        assert_in_delta 0.6, row.conversion_rate
      end

      test "k of the cohort of the period: i × c, the referees of its teachers per teacher" do
        viral = metrics.viral

        assert_equal [ 3, 4, 2 ], [ viral.cohort_size, viral.shares, viral.referees ]
        assert_in_delta 2.0 / 3, viral.k
        assert_in_delta viral.invitations_per_user * viral.conversion_rate, viral.k
      end

      test "the viral cycle: median days between the referrer's and the referee's sign-ups" do
        assert_in_delta 10.0, metrics.viral_cycle_days, 0.01 # 40, 3 and 10 days
      end

      test "the best referrers, the students per active teacher, the ranking of schools, the pending requests" do
        row = metrics

        assert_equal [ [ "Aya Koné", "Lycée Classique d'Abidjan", 2 ], [ "Ancien Koné", "Lycée Classique d'Abidjan", 1 ] ],
                     row.top_referrers.map { [ it.name, it.school_name, it.referrals_count ] }
        assert_equal [ 3, 4 ], [ row.students_joined, row.active_teachers ]
        assert_in_delta 0.75, row.students_per_teacher
        assert_equal [ [ @school.public_id, "Lycée Classique d'Abidjan", "Abidjan 1", 4 ] ],
                     row.schools_leaderboard.map { [ it.public_id, it.name, it.drena_name, it.teachers_count ] }
        assert_equal 1, row.pending_count
        assert_equal [ "Lycée Classique d'Abidjan" ], row.oldest_pending.map(&:school_name)
      end

      test "m7: pending or refused accounts are neither sign-ups nor cohort; sponsored referrals do not convert shares" do
        create_join_request(teacher: create_teacher(school: nil, created_at: NOW - 5.days))
        create_join_request(teacher: create_teacher(school: nil, created_at: NOW - 4.days), status: "rejected")
        approved = create_teacher(school: @school, created_at: NOW - 3.days)
        create_join_request(school: @school, teacher: approved, status: "approved")
        create_referral(referrer: @aya, referee: approved, source: "sponsor", created_at: NOW - 3.days)

        row = metrics

        assert_equal [ 4, 4 ], [ row.teacher_signups, row.viral.cohort_size ]
        assert_equal 4, row.referred_signups
        assert_in_delta 0.6, row.conversion_rate, 0.001, "3 parrainages par lien pour 5 partages"
        assert_equal 2, row.viral.referees, "les filleuls par lien de la cohorte"
      end

      test "m7: an inactive school is not ranked" do
        closed = create_school(status: "inactive")
        3.times { create_teacher(school: closed) }

        assert_equal [ @school.public_id ], metrics.schools_leaderboard.map(&:public_id)
      end

      # ADR-0036, amendment (2): its membership stays, closed, but a deleted account is no longer a student who joined.
      test "a student account deleted on request no longer counts among the students who joined" do
        Orm::User.where(role: "student").first.update!(anonymized_at: NOW - 1.day)

        assert_equal 2, metrics.students_joined
      end

      test "an empty period: zeros, and no division by zero" do
        row = GrowthMetricsQuery.new.call(from: NOW + 1.day, to: NOW + 2.days)

        assert_equal [ 0, 0, 0, 0 ], [ row.shares, row.teacher_signups, row.referred_signups, row.students_joined ]
        assert_nil row.conversion_rate
        assert_nil row.viral.k
        assert_nil row.viral_cycle_days
        assert_empty row.top_referrers
        assert_nil GrowthMetricsQuery::Row.new(**row.to_h.merge(active_teachers: 0)).students_per_teacher
      end

      test "four queries, whatever the volume" do
        few = count_queries { metrics }
        5.times { create_referral(referrer: create_teacher(school: create_school, created_at: NOW - 2.days), created_at: NOW - 1.day) }
        10.times { create_referral_share(user: @awa, created_at: NOW - 1.day) }

        assert_equal 4, few
        assert_equal few, count_queries { metrics }
      end
    end
  end
end
