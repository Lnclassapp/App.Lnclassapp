require "test_helper"

module Queries
  module Classroom
    # Chantier acquisition-classes, lot A, PRD §3.1 : chaque définition de l'entonnoir des classes, lue en direct sur les tables.
    class ClassAdoptionQueryTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 11, 16)

      # La base de test porte les établissements et classes du jeu de référence : on les retire (dans la transaction du test)
      # pour que chaque compte vienne de la fabrication du test seule.
      setup do
        Orm::Classroom.delete_all
        Orm::School.delete_all
        travel_to Time.zone.local(2026, 11, 16, 12)
      end

      def result = ClassAdoptionQuery.new.call(today: TODAY)
      def total = result.total
      def classroom_with(count, school: create_school, sessions: 0, **)
        create_classroom(school:, **).tap do |classroom|
          students = Array.new(count) { create_student(classroom:) }
          students.first(sessions).each { create_exercise_session(student: it) }
        end
      end
      def taught(teacher) = Orm::TeacherClassroom.find_by!(teacher:).classroom
      def anonymize(user) = user.update_columns(anonymized_at: Time.current)

      test "chaque étage de l'entonnoir : inscrit, classe ouverte, cochée, peuplée, devoir, adoptée" do
        create_teacher(school: create_school)
        create_teacher(classrooms: [ classroom_with(0) ])
        adopted = create_teacher(classrooms: [ classroom_with(5, sessions: 5) ])
        create_assignment(by: adopted, classroom: taught(adopted))

        assert_equal [ 3, 1, 2, 2, 1, 1, 1 ], total.to_h.values
      end

      test "quatre élèves qui travaillent ne font pas une classe adoptée, cinq sans exercice non plus" do
        create_teacher(classrooms: [ classroom_with(4, sessions: 4) ])
        create_teacher(classrooms: [ classroom_with(5, sessions: 0) ])

        assert_equal 0, total.e6
        assert_equal 2, total.e4
      end

      test "un enseignant sans établissement principal n'est pas inscrit" do
        create_teacher(school: nil)

        assert_equal 0, total.e1
      end

      test "une classe de l'année passée ou archivée ne compte pas : inscrit mais pas coché" do
        school = create_school
        old = create_classroom(school:, school_year: "2025-2026")
        archived = create_classroom(school:, status: "archived")
        create_teacher(school:, classrooms: [ old, archived ])

        assert_equal [ 1, 1, 0, 0, 0, 0, 0 ], total.to_h.values
      end

      test "l'établissement principal compte, pas un établissement secondaire" do
        open_school = create_school
        create_classroom(school: open_school)
        teacher = create_teacher(school: create_school)
        add_teacher_school(teacher, open_school)

        assert_equal [ 1, 1, 0 ], total.to_h.values.first(3)
      end

      test "les comptes anonymisés sont exclus : enseignant et élève" do
        gone = create_teacher(classrooms: [ classroom_with(1) ])
        anonymize(gone)
        classroom = create_classroom
        kept = create_teacher(classrooms: [ classroom ])
        ghost = create_student(classroom:)
        anonymize(ghost)

        assert_equal [ 1, 0, 1, 1, 0, 0, 0 ], total.to_h.values
        # L'élève de la classe de l'enseignant anonymisé reste compté, sans enseignant ; le fantôme de la classe de `kept` ne l'est pas.
        assert_equal({ "with_teacher" => {}, "without_teacher" => { "standard" => 1 } }, result.students)
        assert_nil result.median_students
        assert_equal 1, Orm::TeacherClassroom.where(teacher: kept).count
      end

      test "une élève parti de la classe ou rattaché à une classe secondaire ne compte pas dans le peuplement" do
        classroom = create_classroom
        create_teacher(classrooms: [ classroom ])
        left = create_student(classroom:)
        Orm::ClassroomStudent.find_by!(student: left).update_columns(left_at: Time.current)
        side = create_student
        Orm::ClassroomStudent.create!(classroom:, student: side, primary: false, joined_at: Time.current, joined_via: "code")

        assert_equal 0, total.e4
        assert_equal({}, result.students["with_teacher"])
      end

      test "par voie d'inscription et par mois d'inscription" do
        create_teacher(joined_via: "direction", created_at: Time.zone.local(2026, 10, 3), school: create_school)
        create_teacher(joined_via: "code", created_at: Time.zone.local(2026, 11, 2), classrooms: [ classroom_with(1) ])
        create_teacher(joined_via: "code", created_at: Time.zone.local(2026, 11, 9), school: create_school)

        data = result
        assert_equal %w[2026-10 2026-11], data.by_month.keys
        assert_equal [ 1, 1 ], data.by_month["2026-10"].to_h.values.values_at(0, 1)
        assert_equal [ 2, 1, 1, 1, 1 ], data.by_month["2026-11"].to_h.values.first(5)
        assert_equal 2, data.by_channel["code"].e1
        assert_equal 1, data.by_channel["direction"].e1
        assert_equal 0, data.by_channel["team"].e1
      end

      test "l'indice sépare les classes vides avec ou sans devoir" do
        with_assignment = create_teacher(classrooms: [ classroom_with(0) ])
        create_assignment(by: with_assignment, classroom: taught(with_assignment))
        create_teacher(classrooms: [ classroom_with(0) ])
        populated = create_teacher(classrooms: [ classroom_with(2) ])
        create_assignment(by: populated, classroom: taught(populated))

        assert_equal 1, result.empty_with_assignment
        assert_equal 1, result.empty_without_assignment
      end

      test "un devoir donné à une autre classe que la classe vide cochée n'est pas un devoir à une classe vide" do
        teacher = create_teacher(classrooms: [ classroom_with(0) ])
        create_assignment(by: teacher, classroom: create_classroom)

        assert_equal 0, result.empty_with_assignment
        assert_equal 1, result.empty_without_assignment
        assert_equal 1, total.e5
      end

      test "les élèves se répartissent selon que la classe a un enseignant, par voie" do
        alone = create_classroom
        create_student(classroom: alone, joined_via: "standard")
        ticked = create_classroom
        create_teacher(classrooms: [ ticked ])
        create_student(classroom: ticked, joined_via: "code")
        create_student(classroom: ticked, joined_via: "code")
        create_student(classroom: ticked, joined_via: "link")
        gone = create_classroom
        anonymize(create_teacher(classrooms: [ gone ]))
        create_student(classroom: gone, joined_via: "link")

        assert_equal({ "code" => 2, "link" => 1 }, result.students["with_teacher"])
        assert_equal({ "standard" => 1, "link" => 1 }, result.students["without_teacher"])
      end

      test "la médiane porte sur les classes cochées et peuplées" do
        create_teacher(classrooms: [ classroom_with(2), classroom_with(5), classroom_with(0) ])
        classroom_with(40)

        assert_equal 3.5, result.median_students
      end

      test "les écoles du CRM par étape saisie, croisées avec l'usage réel" do
        author = create_user(role: "team")
        demo = create_school
        Orm::CrmAccount.create!(school: demo, stage: "demo_done", stage_changed_at: Time.current)
        Orm::CrmInteraction.create!(school: demo, author:, kind: "call", occurred_at: 2.days.ago, outcome: "positive")
        Orm::CrmInteraction.create!(school: demo, author:, kind: "visit", occurred_at: 40.days.ago, outcome: "neutral")
        classroom = create_classroom(school: demo)
        create_student(classroom:)
        create_teacher(school: demo)
        bare = create_school
        create_classroom(school: bare)
        create_school(status: "inactive")

        rows = result.crm_stages.index_by(&:stage)
        assert_equal %w[prospect demo_done subscribed lost], result.crm_stages.map(&:stage)
        assert_equal [ 1, 1, 1, 1, 1 ], rows["demo_done"].to_h.values.drop(1)
        assert_equal [ 1, 0, 0, 1, 0 ], rows["prospect"].to_h.values.drop(1)
        assert_equal [ 0, 0, 0, 0, 0 ], rows["lost"].to_h.values.drop(1)
        assert_equal 1, result.crm_interactions_30d
        assert_equal 1, result.verdict_counters[:crm_schools_with_interaction]
      end

      test "le compteur du verdict reprend l'entonnoir total et les indices" do
        create_teacher(classrooms: [ classroom_with(2) ])

        counters = result.verdict_counters
        assert_equal({ e1: 1, blocked: 0, e2: 1, e3: 1, e4: 1, e5: 0, e6: 0, empty_with_assignment: 0, empty_without_assignment: 0,
                       crm_schools_with_interaction: 0, median_students_per_populated_class: 2.0 }, counters)
      end

      test "une base vide rend des zéros" do
        data = result

        assert_equal [ 0 ] * 7, data.total.to_h.values
        assert_empty data.by_month
        assert_equal 0, data.crm_interactions_30d
        assert_equal [ 0, 0, 0, 0, 0 ], data.crm_stages.first.to_h.values.drop(1)
      end
    end
  end
end
