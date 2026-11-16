require "test_helper"

# ADR-XXXX-notifications-web-push-aux-eleves §3.2 ; PRD §3.1 « exercice commencé » : session ouverte depuis plus de 24 h, sans réponse
# depuis 24 h, commencée il y a moins de 7 jours, non close ; élèves abonnés, non coupés, non anonymisés.
module Queries
  module Communication
    class PushCandidates
      class UnfinishedTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        setup do
          @material = create_material(name: "SVT")
          @exercise = create_exercise(course: create_course(material: @material))
          @student = create_student
          create_push_subscription(user: @student)
        end

        def session_started(ago, student: @student, status: "started", exercise: create_exercise(course: @exercise.course))
          create_exercise_session(student:, exercise:, status:).tap { it.update_columns(started_at: NOW - ago) }
        end

        def candidates = Unfinished.new.for(now: NOW)

        test "ouverte depuis 30 h sans réponse : un candidat avec sa clé, l'URL de la session, la matière seule, valable jusqu'à 7 jours" do
          session = session_started(30.hours)

          found = candidates.sole

          assert_equal @student.id, found.user_id
          assert_equal "unfinished", found.motive
          assert_equal "unfinished:#{session.public_id}", found.object_key
          assert_equal "/sessions/#{session.public_id}", found.url
          assert_equal({ material: "SVT" }, found.variables)
          assert_equal NOW - 30.hours + 7.days, found.valid_until
        end

        test "ouverte depuis moins de 24 h, ou depuis 7 jours et plus : rien" do
          session_started(23.hours)
          session_started(7.days)
          session_started(10.days)

          assert_empty candidates
        end

        test "une réponse dans les dernières 24 h : rien ; une réponse plus ancienne : le candidat reste" do
          recent = session_started(40.hours)
          create_attempt(session: recent)
          Orm::QuestionAttempt.where(exercise_session: recent).update_all(answered_at: NOW - 2.hours)
          old = session_started(40.hours)
          create_attempt(session: old)
          Orm::QuestionAttempt.where(exercise_session: old).update_all(answered_at: NOW - 30.hours)

          assert_equal [ old.public_id ], candidates.map { it.object_key.delete_prefix("unfinished:") }
        end

        test "une session terminée ou abandonnée : rien" do
          session_started(30.hours, status: "completed")
          session_started(30.hours, status: "abandoned")

          assert_empty candidates
        end

        test "un élève non abonné, qui a coupé ou anonymisé : rien" do
          session_started(30.hours, student: create_student)
          off = create_student
          create_push_subscription(user: off)
          create_push_preference(user: off, turned_off_at: NOW - 1.day)
          anonymized = create_student
          create_push_subscription(user: anonymized)
          anonymized.update_columns(anonymized_at: NOW)
          [ off, anonymized ].each { session_started(30.hours, student: it) }

          assert_empty candidates
        end

        test "un nombre fixe de lectures quel que soit le nombre de sessions" do
          session_started(30.hours)
          few = query_count { candidates }
          3.times { session_started(30.hours, student: create_student.tap { create_push_subscription(user: it) }) }

          assert_equal few, query_count { candidates }
          assert_equal 1, few
        end

        def query_count
          count = 0
          counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
          count
        end
      end
    end
  end
end
