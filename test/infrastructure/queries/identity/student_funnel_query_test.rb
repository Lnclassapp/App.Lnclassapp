require "test_helper"

module Queries
  module Identity
    # Chantier entonnoir-aarrr (PRD §3, §5) : l'entonnoir des élèves lu en direct, en nombre de requêtes fixe.
    class StudentFunnelQueryTest < ActiveSupport::TestCase
      NOW = Time.zone.local(2026, 11, 16, 12)
      MONDAY = Time.zone.local(2026, 11, 2, 9) # semaine du 2 novembre
      FROM = NOW - 30.days

      def query = StudentFunnelQuery.new
      def report = query.call(from: FROM, to: NOW, now: NOW)

      def count_queries(&)
        count = 0
        ActiveSupport::Notifications.subscribed(->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }, "sql.active_record", &)
        count
      end

      def passed(student, at:, score: 100, exercise: create_exercise)
        create_exercise_session(student:, exercise:, status: "completed", score_percent: score, started_at: at, completed_at: at)
      end

      setup do
        travel_to NOW
        @classroom = create_classroom
        # Seul, inscrit lundi 2 : lit une notion, réussit deux exercices distincts (dont un repris), revient à J+8.
        @alone = create_student(classroom: @classroom, joined_via: "standard", created_at: MONDAY, first_name: "Aïcha")
        create_essential_read(student: @alone, at: MONDAY + 8.days, first_read_at: MONDAY + 1.hour)
        exercise = create_exercise
        passed(@alone, at: MONDAY + 1.day, exercise:)
        passed(@alone, at: MONDAY + 2.days, exercise:)
        passed(@alone, at: MONDAY + 2.days)
        # Amenée par le lien de sa classe, même semaine : commence un exercice, le rate à 47 %.
        @linked = create_student(classroom: @classroom, joined_via: "link", created_at: MONDAY + 1.day)
        passed(@linked, at: MONDAY + 1.day, score: 47)
        # Amené par l'ancien code, semaine suivante : aucune activité.
        @coded = create_student(classroom: @classroom, joined_via: "code", created_at: MONDAY + 7.days)
        # Hors période, anonymisé, enseignant : jamais comptés.
        create_student(classroom: @classroom, created_at: NOW - 60.days)
        create_student(classroom: @classroom, created_at: MONDAY, anonymized_at: NOW - 1.day)
      end

      test "the weekly funnel, per week and per arrival channel" do
        rows = query.weekly(from: FROM, to: NOW, now: NOW)
        by_key = rows.to_h { [ [ it.week_on, it.channel ], it.steps ] }

        assert_equal [ [ Date.new(2026, 11, 2), "link" ], [ Date.new(2026, 11, 2), "standard" ], [ Date.new(2026, 11, 9), "code" ] ],
                     rows.map { [ it.week_on, it.channel ] }
        assert_equal [ 1, 1, 1, 1, 1, 0 ], by_key.fetch([ Date.new(2026, 11, 2), "standard" ]).to_a
        assert_equal [ 1, 0, 1, 0, 0, 0 ], by_key.fetch([ Date.new(2026, 11, 2), "link" ]).to_a
        assert_equal [ 1, 0, 0, 0, 0, 0 ], by_key.fetch([ Date.new(2026, 11, 9), "code" ]).to_a
      end

      test "a success is read on the mark out of 20 (ADR-0106): 48 % passes, 47 % does not" do
        passed(@coded, at: NOW - 1.day, score: 48)

        assert_equal 2, report.total.passed_one
      end

      test "the first membership gives the channel; a student without membership is apart, once" do
        create_user(role: "student", created_at: MONDAY)
        Orm::ClassroomStudent.create!(classroom: create_classroom, student: @alone, primary: false, joined_at: NOW, joined_via: "link")

        steps = report.groups

        assert_equal({ alone: 1, classroom: 2, none: 1 }, steps.transform_values(&:signed_up))
        assert_equal 4, report.total.signed_up
      end

      test "the rates of each step over the sign-ups, nil without sign-up" do
        total = report.total

        assert_in_delta 2.0 / 3, total.rate(:started)
        assert_in_delta 1.0 / 3, total.rate(:passed_one)
        assert_nil StudentFunnelQuery::Steps.zero.rate(:passed_one)
        assert_equal [ 0, 0, 0, 0, 0, 0 ], report.groups.fetch(:none).to_a
      end

      test "the median delay from sign-up to the first success, per group and in total" do
        late = create_student(classroom: @classroom, created_at: MONDAY)
        passed(late, at: MONDAY + 10.days)
        early = create_student(classroom: @classroom, joined_via: "link", created_at: MONDAY + 3.days)
        passed(early, at: MONDAY + 2.days) # reprise : un succès daté d'avant l'inscription compte 0 jour

        medians = report.median_activation_days

        assert_in_delta 1.0, medians.fetch(:total), 0.01 # 0, 1 et 10 jours
        assert_in_delta 5.5, medians.fetch(:alone), 0.01
        assert_in_delta 0.0, medians.fetch(:classroom), 0.01
        assert_nil medians[:none]
      end

      test "retention: back at D+n or later, measurable only once D+n has passed" do
        cohorts = report.cohorts

        assert_equal [ Date.new(2026, 11, 2), Date.new(2026, 11, 9) ], cohorts.map(&:week_on)
        first = cohorts.first
        assert_equal 2, first.signed_up
        assert_equal [ 2, 1 ], [ first.retention.fetch(1).eligible, first.retention.fetch(1).retained ]
        assert_equal [ 2, 1 ], [ first.retention.fetch(7).eligible, first.retention.fetch(7).retained ]
        assert_in_delta 0.5, first.retention.fetch(7).rate
        assert_equal 0, first.retention.fetch(30).eligible
        assert_nil first.retention.fetch(30).rate
      end

      test "an answer or a closing counts as activity" do
        session = create_exercise_session(student: @coded, started_at: MONDAY + 7.days)
        travel_to(MONDAY + 14.days + 1.hour) { create_attempt(session:) }

        assert_equal 1, report.cohorts.last.retention.fetch(7).retained
      end

      test "revenue: cards activated in the period, their amount, the students subscribed today" do
        Orm::Billing::ActivationCard.where(state: "activated").order(:serial).first.update!(student_id: @alone.id)

        revenue = report.revenue

        assert_equal [ 3, 30_000, 1 ], [ revenue.activated_cards, revenue.amount_xof, revenue.subscribed_students ]
        assert_predicate revenue, :beta_open
        assert_equal [ 0, 0 ], query.call(from: NOW - 1.day, to: NOW, now: NOW).revenue.then { [ it.activated_cards, it.amount_xof ] }
      end

      test "the beta closes on Offer::BETA_ENDS_ON" do
        stub_const(Entities::Billing::Offer, :BETA_ENDS_ON, NOW.to_date) do
          assert_not report.revenue.beta_open
        end
      end

      test "an empty period: zero everywhere, no cohort, no median" do
        empty = query.call(from: NOW - 1.hour, to: NOW, now: NOW)

        assert_equal 0, empty.total.signed_up
        assert_empty empty.cohorts
        assert_nil empty.median_activation_days[:total]
      end

      test "a fixed number of queries, whatever the number of students" do
        few = count_queries { report }
        20.times { passed(create_student(classroom: @classroom, created_at: MONDAY), at: MONDAY + 1.day) }

        assert_equal few, count_queries { report }
        assert_operator few, :<=, 3
      end
    end
  end
end
