require "test_helper"

# ADR envois de notifications §6 ; PRD §3.1 « nouveaux exercices » : exercices donnés depuis moins de 24 h à la classe principale,
# du niveau de l'élève, pas encore tous rendus ; un envoi = une notification, quel que soit son nombre d'exercices.
module Queries
  module Communication
    class PushCandidates
      class AssignmentNewTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)

        setup do
          @classroom = create_classroom
          @material = create_material(name: "Mathématiques")
          @course = create_course(material: @material, level: @classroom.level)
          @teacher = create_teacher
          @student = create_student(classroom: @classroom)
          create_push_subscription(user: @student)
        end

        def send_sheet(size, assigned_at: NOW - 2.hours, batch: "B#{factory_sequence}".ljust(14, "0"), course: @course, classroom: @classroom)
          Array.new(size) do
            create_assignment(classroom:, assignable: create_exercise(course:), by: @teacher, batch_public_id: batch, due_on: nil, assigned_at:)
          end
        end

        def found(now: NOW) = AssignmentNew.new.for(now:)

        test "trois exercices donnés il y a 2 h : un seul candidat, le nombre et la matière dans les variables, valable 24 h après l'envoi" do
          send_sheet(3, batch: "NEW".ljust(14, "0"))

          candidate = found.sole

          assert_equal @student.id, candidate.user_id
          assert_equal "assignment_new", candidate.motive
          assert_equal "assignment_new:#{'NEW'.ljust(14, '0')}", candidate.object_key
          assert_equal({ material: "Mathématiques", count: 3 }, candidate.variables)
          assert_equal NOW - 2.hours + 24.hours, candidate.valid_until
          assert_equal "Ton prof de Mathématiques t'a donné 3 exercices.", Entities::Communication::PushMessage.for(candidate).body
        end

        test "un seul exercice : le singulier" do
          send_sheet(1)

          assert_equal "Ton prof de Mathématiques t'a donné 1 exercice.", Entities::Communication::PushMessage.for(found.sole).body
        end

        test "donné il y a plus de 24 h ou dans le futur : rien" do
          send_sheet(2, assigned_at: NOW - 24.hours - 1.minute)
          send_sheet(2, assigned_at: NOW + 1.minute)

          assert_empty found
        end

        test "tous les exercices rendus : rien ; un seul rendu sur trois : l'envoi reste annoncé" do
          done = send_sheet(2, batch: "DONE".ljust(14, "0"))
          partial = send_sheet(3, batch: "PART".ljust(14, "0"))
          [ done, partial.first(1) ].flatten.each do |assignment|
            create_exercise_session(student: @student, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed", classroom_assignment: assignment)
          end

          assert_equal [ "assignment_new:#{'PART'.ljust(14, '0')}" ], found.map(&:object_key)
        end

        test "UDR-0013 : un exercice d'un autre niveau que celui de l'élève n'est ni annoncé ni compté" do
          send_sheet(2, course: create_course(material: @material, level: create_level), batch: "OTHER".ljust(14, "0"))
          send_sheet(1, batch: "MIX".ljust(14, "0"))
          send_sheet(1, batch: "MIX".ljust(14, "0"), course: create_course(material: @material, level: create_level))

          candidates = found

          assert_equal [ "assignment_new:#{'MIX'.ljust(14, '0')}" ], candidates.map(&:object_key)
          assert_equal 1, candidates.sole.variables[:count]
        end

        test "un élève non abonné, ou d'une autre classe, ne reçoit rien" do
          send_sheet(2, classroom: create_classroom)
          create_student(classroom: @classroom)

          assert_empty found
        end

        test "la relecture pour un seul élève ne rend que cet élève" do
          send_sheet(2)
          other = create_student(classroom: @classroom).tap { create_push_subscription(user: it) }

          assert_equal [ other.id ], AssignmentNew.new.for(now: NOW, user_ids: [ other.id ]).map(&:user_id)
        end

        test "la source est branchée dans PushCandidates" do
          send_sheet(2)

          assert_equal [ "assignment_new" ], Queries::Communication::PushCandidates.new.for(now: NOW).map(&:motive).uniq
        end
      end
    end
  end
end
