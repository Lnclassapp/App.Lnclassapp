require "test_helper"

# ADR-XXXX-notifications-web-push-aux-eleves §3.2 ; PRD §3.1 « résultat » : copie rendue hors ligne reçue depuis moins de 24 h, ou médaille
# obtenue depuis 2 h à 24 h, pour un élève non revenu depuis ; une seule notification par session.
module Queries
  module Communication
    class PushCandidates
      class ResultTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        setup do
          @exercise = create_exercise(course: create_course(material: create_material(name: "Anglais")))
          @student = create_student
          create_push_subscription(user: @student)
        end

        def completed(at, student: @student, received_at: nil)
          create_exercise_session(student:, exercise: create_exercise(course: @exercise.course), status: "completed")
            .tap { it.update_columns(started_at: at - 10.minutes, completed_at: at, received_at:) }
        end

        def medal(session, at)
          create_badge(student: session.student, exercise: session.exercise, session:, level: "gold").tap { it.update_columns(awarded_at: at) }
        end

        def candidates = Result.new.for(now: NOW)

        test "copie hors ligne reçue depuis 3 h : un candidat copy avec la clé, l'URL du résultat et la matière" do
          session = completed(NOW - 3.hours, received_at: NOW - 3.hours)

          found = candidates.sole

          assert_equal "result", found.motive
          assert_equal "result:#{session.public_id}", found.object_key
          assert_equal "/sessions/#{session.public_id}/result", found.url
          assert_equal({ kind: "copy", material: "Anglais" }, found.variables)
          assert_equal NOW - 3.hours + 24.hours, found.valid_until
        end

        test "user_ids limits the candidates to the given students" do
          other = create_student
          create_push_subscription(user: other)
          completed(NOW - 3.hours, received_at: NOW - 3.hours)
          completed(NOW - 3.hours, student: other, received_at: NOW - 3.hours)

          assert_equal 2, candidates.size
          assert_equal [ other.id ], Result.new.for(now: NOW, user_ids: [ other.id ]).map(&:user_id)
        end

        test "copie reçue à l'instant ou depuis plus de 24 h : rien pour la plus ancienne ; la copie fraîche est notifiée sans délai" do
          completed(NOW - 25.hours, received_at: NOW - 25.hours)
          fresh = completed(NOW - 5.minutes, received_at: NOW - 5.minutes)

          assert_equal [ "result:#{fresh.public_id}" ], candidates.map(&:object_key)
        end

        test "médaille obtenue depuis 3 h : un candidat medal ; depuis moins de 2 h ou plus de 24 h : rien" do
          session = completed(NOW - 3.hours)
          medal(session, NOW - 3.hours)
          [ NOW - 1.hour, NOW - 26.hours ].each do |at|
            other = create_student.tap { create_push_subscription(user: it) }
            medal(completed(at, student: other), at)
          end

          found = candidates.sole

          assert_equal "result:#{session.public_id}", found.object_key
          assert_equal({ kind: "medal", material: "Anglais" }, found.variables)
        end

        test "copie reçue et médaille de la même session : une seule notification, la copie" do
          session = completed(NOW - 4.hours, received_at: NOW - 4.hours)
          medal(session, NOW - 4.hours)

          assert_equal [ "copy" ], candidates.map { it.variables[:kind] }
        end

        test "l'élève est revenu depuis : rien ; la fermeture elle-même n'est pas un retour" do
          returned = create_student
          create_push_subscription(user: returned)
          completed(NOW - 5.hours, student: returned, received_at: NOW - 5.hours)
          create_exercise_session(student: returned).update_columns(started_at: NOW - 1.hour)
          medal_session = completed(NOW - 5.hours, student: returned)
          medal(medal_session, NOW - 5.hours)
          calm = completed(NOW - 5.hours, received_at: NOW - 5.hours)

          assert_equal [ "result:#{calm.public_id}" ], candidates.map(&:object_key)
        end

        test "un élève non abonné, qui a coupé ou anonymisé : rien" do
          completed(NOW - 5.hours, student: create_student, received_at: NOW - 5.hours)
          off = create_student
          create_push_subscription(user: off)
          create_push_preference(user: off, turned_off_at: NOW - 1.day)
          anonymized = create_student
          create_push_subscription(user: anonymized)
          anonymized.update_columns(anonymized_at: NOW)
          [ off, anonymized ].each { completed(NOW - 5.hours, student: it, received_at: NOW - 5.hours) }

          assert_empty candidates
        end

        test "sans événement : vide, sans lire l'activité" do
          assert_empty candidates
        end

        test "un nombre fixe de lectures quel que soit le nombre d'élèves" do
          completed(NOW - 5.hours, received_at: NOW - 5.hours)
          few = query_count { candidates }
          3.times do
            student = create_student.tap { create_push_subscription(user: it) }
            medal(completed(NOW - 5.hours, student:), NOW - 5.hours)
          end

          assert_equal few, query_count { candidates }
          assert_equal 3, few
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
