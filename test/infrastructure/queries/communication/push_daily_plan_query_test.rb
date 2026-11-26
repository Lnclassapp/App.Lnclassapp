require "test_helper"

module Queries
  module Communication
    # ADR XXXX (envois de notifications) §4.4 : par motif à valider, les élèves distincts, les établissements et le texte ;
    # jamais un nom d'élève ; ni les motifs automatiques, ni l'annonce, ni les élèves déjà prévenus.
    class PushDailyPlanQueryTest < ActiveSupport::TestCase
      Candidate = Entities::Communication::PushCandidate
      NOW = Time.utc(2026, 11, 25, 10, 12)

      class FakeCandidates
        include Ports::Communication::PushCandidatesPort

        def initialize(list) = @list = list
        def for(now:, user_ids: nil) = @list
      end

      setup do
        @lycee = create_school(name: "Lycée Alpha")
        @college = create_school(name: "Collège Bêta")
        @alpha = create_classroom(school: @lycee)
        @beta = create_classroom(school: @college)
        @ada = create_student(classroom: @alpha, first_name: "Ada", last_name: "Zongo")
        @bob = create_student(classroom: @alpha, first_name: "Bob", last_name: "Yao")
        @cle = create_student(classroom: @beta, first_name: "Clémence", last_name: "Xavier")
      end

      def candidate(user, motive = "inactive", key: "#{motive}:3", variables: {}, valid_until: nil)
        Candidate.new(user_id: user.id, motive:, object_key: key, url: "/eleve", variables:, valid_until:)
      end

      def plan(list, now: NOW) = PushDailyPlanQuery.new(candidates: FakeCandidates.new(list)).call(now:)
      def entry(entries, motive) = entries.find { it.motive == motive }

      test "3 students of 2 schools: distinct students, schools by size, the exact text, and no name anywhere" do
        entries = plan([ @ada, @bob, @cle ].map { candidate(it) })
        inactive = entry(entries, "inactive")

        assert_equal 3, inactive.students
        assert_equal [ [ "Lycée Alpha", 2 ], [ "Collège Bêta", 1 ] ], inactive.schools
        assert_equal I18n.t("communication.push.messages.inactive.body"), inactive.text
        assert_equal 0, inactive.more_texts
        assert_nil inactive.approval
        assert_no_match(/Ada|Zongo|Bob|Yao|Clémence|Xavier/, inactive.inspect)
      end

      test "a student concerned by two objects of the same motive counts once" do
        entries = plan([ candidate(@ada, key: "inactive:3"), candidate(@ada, key: "inactive:7") ])

        assert_equal 1, entry(entries, "inactive").students
      end

      test "lists the motives in priority order, with no student for a motive nobody is concerned by" do
        entries = plan([ candidate(@ada, "result", key: "result:1", variables: { kind: "copy", material: "Maths" }), candidate(@bob) ])

        assert_equal %w[quiz_prep assignment_due assignment_new unfinished result inactive], entries.map(&:motive)
        assert_equal 0, entry(entries, "unfinished").students
        assert_equal [ 1, 1 ], [ entry(entries, "result").students, entry(entries, "inactive").students ]
      end

      test "automatic motives and the announcement are absent" do
        create_push_motive_setting(motive: "quiz_prep", automatic: true)
        entries = plan([ candidate(@ada, "quiz_prep", variables: { material: "Maths", count: 2 }), candidate(@ada, "announcement", key: "announcement:1") ])

        assert_equal %w[assignment_due assignment_new unfinished result inactive], entries.map(&:motive)
      end

      test "excludes expired candidates and students who already received the object" do
        create_push_delivery(user: @ada, motive: "inactive", object_key: "inactive:3", status: "delivered")
        create_push_delivery(user: @bob, motive: "inactive", object_key: "inactive:3", status: "disabled")
        entries = plan([ candidate(@ada), candidate(@bob), candidate(@cle, valid_until: NOW - 1) ])

        assert_equal 1, entry(entries, "inactive").students
        assert_equal [ [ "Lycée Alpha", 1 ] ], entry(entries, "inactive").schools
      end

      test "several texts: the most common one first and the number of others" do
        entries = plan([ candidate(@ada, "result", key: "r:1", variables: { kind: "copy", material: "Maths" }),
                         candidate(@bob, "result", key: "r:2", variables: { kind: "copy", material: "Maths" }),
                         candidate(@cle, "result", key: "r:3", variables: { kind: "copy", material: "Français" }) ])
        result = entry(entries, "result")

        assert_equal I18n.t("communication.push.messages.result.copy.body", material: "Maths"), result.text
        assert_equal 1, result.more_texts
      end

      test "an approved motive carries who, when and how many were recorded, the team member by first name and initial" do
        approver = create_team_member(first_name: "Awa", last_name: "Koné")
        create_push_approval(motive: "inactive", on_date: NOW.to_date, approved_by: approver, approved_at: NOW - 1.hour,
                             recipients: [ [ @ada.id, "inactive:3" ], [ @bob.id, "inactive:3" ] ])
        approval = entry(plan([ candidate(@ada) ]), "inactive").approval

        assert_equal [ "Awa K.", NOW - 1.hour, 2 ], [ approval.by_name, approval.at, approval.count ]
      end

      test "a fixed number of reads however many students" do
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        list = [ @ada, @bob, @cle ].map { candidate(it) }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { plan(list) }

        assert_operator count, :<=, 8
      end
    end
  end
end
