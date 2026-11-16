require "test_helper"

# ADR-XXXX-notifications-web-push-aux-eleves §3.2 ; PRD §3.1 « devoir à rendre » et « préparer une interro » : la feuille de la classe
# principale active, échéance demain (date d'Abidjan), au moins un exercice non rendu ; 1-2 exercices = interro, 3 ou plus = devoir.
module Queries
  module Communication
    class PushCandidates
      class AssignmentDueTest < ActiveSupport::TestCase
        NOW = Time.utc(2026, 11, 18, 12, 30)
        TOMORROW = Date.new(2026, 11, 19)

        setup do
          @classroom = create_classroom
          @material = create_material(name: "Mathématiques")
          @course = create_course(material: @material, level: @classroom.level)
          @teacher = create_teacher
        end

        def student_in(classroom = @classroom, subscribed: true)
          create_student(classroom:).tap { |student| create_push_subscription(user: student) if subscribed }
        end

        # Un envoi de `size` exercices, dû à `due`; renvoie les assignations.
        def send_sheet(size, due: TOMORROW, classroom: @classroom, batch: "B#{factory_sequence}".ljust(14, "0"))
          Array.new(size) do
            create_assignment(classroom:, assignable: create_exercise(course: @course), by: @teacher, batch_public_id: batch, due_on: due,
                                assigned_at: NOW - 1.day)
          end
        end

        def hand_in(student, assignment)
          create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                                  classroom_assignment: assignment)
        end

        def assignment_due(now: NOW) = AssignmentDue.new.for(now:)
        def quiz_prep(now: NOW) = QuizPrep.new.for(now:)

        test "UDR-0013: a sheet whose course is of another level than the student's gives no candidate, for the devoir and the interro" do
          other_course = create_course(material: @material, level: create_level)
          [ 3, 1 ].each do |size|
            Array.new(size) do
              create_assignment(classroom: @classroom, assignable: create_exercise(course: other_course), by: @teacher,
                                batch_public_id: "N#{size}".ljust(14, "0"), due_on: TOMORROW, assigned_at: NOW - 1.day)
            end
          end
          student_in

          assert_empty assignment_due
          assert_empty quiz_prep
        end

        test "UDR-0013: only the exercises of the student's level count in a mixed sheet" do
          other_course = create_course(material: @material, level: create_level)
          batch = "MIX".ljust(14, "0")
          [ @course, @course, other_course ].each do |course|
            create_assignment(classroom: @classroom, assignable: create_exercise(course:), by: @teacher, batch_public_id: batch, due_on: TOMORROW,
                              assigned_at: NOW - 1.day)
          end
          student_in

          assert_empty assignment_due
          assert_equal [ "quiz_prep:#{batch}" ], quiz_prep.map(&:object_key)
        end

        test "UDR-0013: a class of another school year still gives its level to its student (the last known level)" do
          @classroom.update_columns(school_year: "2019-2020")
          send_sheet(3)
          student = student_in

          assert_equal [ student.id ], assignment_due.map(&:user_id)
        end

        test "user_ids limits the candidates to the given students" do
          send_sheet(3)
          send_sheet(1)
          first = student_in
          second = student_in

          assert_equal [ first.id, second.id ].sort, assignment_due.map(&:user_id).sort
          assert_equal [ second.id ], AssignmentDue.new.for(now: NOW, user_ids: [ second.id ]).map(&:user_id)
          assert_equal [ second.id ], QuizPrep.new.for(now: NOW, user_ids: [ second.id ]).map(&:user_id)
        end

        test "une feuille de 3 exercices due demain : un candidat assignment_due avec la matière, le lien de la feuille, valable jusqu'à 20 h" do
          assignments = send_sheet(3)
          student = student_in

          found = assignment_due.sole
          batch = assignments.first.batch_public_id

          assert_equal student.id, found.user_id
          assert_equal "assignment_due", found.motive
          assert_equal "assignment_due:#{batch}", found.object_key
          assert_equal "/students/classroom#devoir-#{batch.downcase}", found.url
          assert_equal({ material: "Mathématiques" }, found.variables)
          assert_equal Time.utc(2026, 11, 18, 20), found.valid_until
          assert_empty quiz_prep
        end

        test "une feuille de 1 ou 2 exercices due demain : un candidat quiz_prep avec la matière et le nombre, jamais assignment_due" do
          student_in
          send_sheet(2, batch: "QUIZ".ljust(14, "0"))

          found = quiz_prep.sole

          assert_equal "quiz_prep", found.motive
          assert_equal "quiz_prep:#{'QUIZ'.ljust(14, '0')}", found.object_key
          assert_equal({ material: "Mathématiques", count: 2 }, found.variables)
          assert_empty assignment_due
        end

        test "une assignation seule sans envoi se repère par son public_id" do
          student_in
          single = create_assignment(classroom: @classroom, assignable: create_exercise(course: @course), by: @teacher, due_on: TOMORROW,
                                     assigned_at: NOW - 1.day)

          assert_equal "quiz_prep:#{single.public_id}", quiz_prep.sole.object_key
        end

        test "une échéance aujourd'hui, après-demain ou absente : rien" do
          student_in
          send_sheet(3, due: NOW.to_date)
          send_sheet(3, due: TOMORROW + 1)
          send_sheet(3, due: nil)

          assert_empty assignment_due
        end

        test "tout rendu : rien ; un seul exercice encore à rendre : le candidat reste" do
          student = student_in
          assignments = send_sheet(3)
          assignments.first(2).each { hand_in(student, it) }

          assert_equal 1, assignment_due.size

          hand_in(student, assignments.last)

          assert_empty assignment_due
        end

        test "la copie rendue d'un camarade ou un exercice commencé sans être rendu ne comptent pas" do
          student = student_in
          other = student_in
          assignments = send_sheet(3)
          assignments.each { hand_in(other, it) }
          create_exercise_session(student:, exercise: Orm::Exercise.find(assignments.first.assignable_id), classroom_assignment: assignments.first)

          assert_equal [ student.id ], assignment_due.map(&:user_id)
        end

        test "classe quittée, classe non principale, classe archivée : rien" do
          send_sheet(3)
          left = student_in
          Orm::ClassroomStudent.find_by!(student: left).update!(left_at: NOW - 1.day)
          secondary = student_in
          Orm::ClassroomStudent.find_by!(student: secondary).update!(primary: false)
          archived = create_classroom(status: "archived")
          student_in(archived)

          assert_empty assignment_due
        end

        test "l'assignation archivée ou l'exercice non publié : rien" do
          student_in
          send_sheet(3, batch: "ARCH".ljust(14, "0")).each { it.update!(status: "archived", archived_at: NOW, archived_by: @teacher) }
          send_sheet(3, batch: "DRAFT".ljust(14, "0")).each { Orm::Exercise.find(it.assignable_id).update_columns(status: "draft") }

          assert_empty assignment_due
        end

        test "un élève non abonné, qui a coupé ou anonymisé : rien" do
          send_sheet(3)
          student_in(subscribed: false)
          off = student_in
          create_push_preference(user: off, turned_off_at: NOW - 1.day)
          anonymized = student_in
          anonymized.update_columns(anonymized_at: NOW)

          assert_empty assignment_due
        end

        test "la feuille d'une autre classe n'arrive pas à l'élève" do
          student_in
          send_sheet(3, classroom: create_classroom)

          assert_empty assignment_due
        end

        test "sans élève abonné ou sans classe : vide" do
          send_sheet(3)
          create_push_subscription(user: create_student)

          assert_empty assignment_due
        end

        def query_count
          count = 0
          counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
          ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
          count
        end

        test "un nombre fixe de lectures quel que soit le nombre d'élèves et de feuilles" do
          student_in
          send_sheet(3)
          few = query_count { assignment_due }
          3.times { student_in; send_sheet(3) }

          assert_equal few, query_count { assignment_due }
          assert_equal 6, few
        end
      end
    end
  end
end
