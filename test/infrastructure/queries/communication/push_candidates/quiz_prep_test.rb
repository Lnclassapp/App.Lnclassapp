require "test_helper"

# ADR-XXXX-notifications-web-push-aux-eleves §3.2 ; PRD §3.1 « préparer une interro » : 1 ou 2 exercices dus demain, non rendus.
# La lecture est celle de AssignmentDue (testée dans assignment_due_test.rb) ; ici le motif, les variables et le seuil.
module Queries
  module Communication
    class PushCandidates
      class QuizPrepTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        setup do
          @classroom = create_classroom
          @course = create_course(material: create_material(name: "Physique-Chimie"), level: @classroom.level)
          @student = create_student(classroom: @classroom)
          create_push_subscription(user: @student)
        end

        def send_sheet(size, batch)
          Array.new(size) do
            create_assignment(classroom: @classroom, assignable: create_exercise(course: @course), by: create_teacher, batch_public_id: batch,
                              due_on: NOW.to_date + 1, assigned_at: NOW - 1.day)
          end
        end

        test "1 puis 2 exercices : le nombre d'exercices de l'envoi dans les variables ; 3 exercices : rien" do
          send_sheet(1, "UN".ljust(14, "0"))
          send_sheet(2, "DEUX".ljust(14, "0"))
          send_sheet(3, "TROIS".ljust(14, "0"))

          found = QuizPrep.new.for(now: NOW).index_by(&:object_key)

          assert_equal [ "quiz_prep:#{'UN'.ljust(14, '0')}", "quiz_prep:#{'DEUX'.ljust(14, '0')}" ].sort, found.keys.sort
          assert_equal({ material: "Physique-Chimie", count: 1 }, found.fetch("quiz_prep:#{'UN'.ljust(14, '0')}").variables)
          assert_equal({ material: "Physique-Chimie", count: 2 }, found.fetch("quiz_prep:#{'DEUX'.ljust(14, '0')}").variables)
          assert_equal @student.id, found.values.first.user_id
        end

        test "le texte du gabarit se compose sans donnée personnelle" do
          send_sheet(2, "QZ".ljust(14, "0"))

          assert_equal "Prépare ton interro de Physique-Chimie de demain : 2 exercices.",
                       Entities::Communication::PushMessage.for(QuizPrep.new.for(now: NOW).sole).body
        end
      end
    end
  end
end
