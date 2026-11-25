require "test_helper"

# ADR-0146 §3.2 ; PRD §3.1 « inactif » : relance aux paliers 3, 7 et 14 jours (date d'Abidjan)
# après la dernière activité, une par palier, puis plus rien sans nouvelle activité ; élèves abonnés, non coupés, non anonymisés.
module Queries
  module Communication
    class PushCandidates
      class InactiveTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        def student_active_at(time, subscribed: true)
          student = create_student
          create_push_subscription(user: student) if subscribed
          create_exercise_session(student:).update_columns(started_at: time, completed_at: nil)
          student
        end

        def candidates(now: NOW) = Inactive.new.for(now:)

        test "aux paliers 3, 7 et 14 jours de différence de date : un candidat avec sa clé, l'accueil, aucune variable" do
          { 3 => Time.utc(2026, 11, 15, 8), 7 => Time.utc(2026, 11, 11, 23, 59), 14 => Time.utc(2026, 11, 4, 0, 1) }.each do |palier, last|
            student = student_active_at(last)
            found = candidates.find { it.user_id == student.id }

            assert_equal "inactive", found.motive
            assert_equal "inactive:#{last.to_date}:#{palier}", found.object_key
            assert_equal "/", found.url
            assert_equal({}, found.variables)
            assert_equal NOW.end_of_day, found.valid_until
            assert_not found.expired?(NOW)
          end
        end

        test "user_ids limits the candidates to the given students" do
          first = student_active_at(Time.utc(2026, 11, 15, 8))
          second = student_active_at(Time.utc(2026, 11, 15, 8))

          assert_equal [ second.id ], Inactive.new.for(now: NOW, user_ids: [ second.id ]).map(&:user_id)
          assert_includes candidates.map(&:user_id), first.id
        end

        test "la différence se compte en dates et non en heures : 2 jours 13 h d écart mais 3 dates" do
          student = student_active_at(Time.utc(2026, 11, 15, 23, 0))

          assert_equal [ "inactive:2026-11-15:3" ], candidates(now: Time.utc(2026, 11, 18, 12, 30)).select { it.user_id == student.id }.map(&:object_key)
        end

        test "entre deux paliers, avant le premier et après 14 jours sans activité : rien" do
          [ 0, 1, 2, 4, 6, 8, 13, 15, 40 ].each do |days|
            student_active_at(NOW - days.days)
          end

          assert_empty candidates
        end

        test "un élève non abonné, qui a coupé, anonymisé, ou sans aucune activité : rien" do
          student_active_at(NOW - 3.days, subscribed: false)
          off = student_active_at(NOW - 3.days)
          create_push_preference(user: off, turned_off_at: NOW - 1.day)
          anonymized = student_active_at(NOW - 3.days)
          anonymized.update_columns(anonymized_at: NOW)
          create_push_subscription(user: create_student)

          assert_empty candidates
        end

        test "un élève avec deux navigateurs donne un seul candidat ; une préférence réactivée ne gêne pas" do
          student = student_active_at(NOW - 3.days)
          create_push_subscription(user: student)
          create_push_preference(user: student, turned_off_at: nil)

          assert_equal [ student.id ], candidates.map(&:user_id)
        end

        test "la requête n'est pas vide sans élève abonné" do
          assert_empty candidates
        end
      end
    end
  end
end
