require "test_helper"

# CL-10 (plan boucle-pedagogique, Lot D4) : le corps de la page d'une classe. La liste des élèves seulement quand
# ReadClassroomPolicy l'accorde. Une classe avec un exercice assigné ne casse plus (CS#B8). ADR-0072 §4.6 : « Cours
# assignés » ne se lit plus, un cours ne s'assignant plus.
module Queries
  module Classroom
    class ClassroomOverviewQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom
      end

      def overview(show_roster: true) = ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster:)

      test "« Cours assignés » ne se lit plus : l'aperçu ne porte que les élèves" do
        assert_equal [ :students ], ClassroomOverviewQuery::Overview.members
        assert_not ClassroomOverviewQuery.const_defined?(:CourseRow, false)
      end

      test "un exercice assigné ne casse rien (CS#B8)" do
        create_assignment(classroom: @classroom, assignable: create_exercise)
        student = create_student(classroom: @classroom)

        assert_equal [ student.public_id ], overview.students.map(&:public_id)
        assert_nil overview(show_roster: false).students
      end

      test "la liste nomme les élèves présents, avec leur numéro et leur dernier score" do
        koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", contact: "0102030405")
        awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        left = create_student(classroom: @classroom, last_name: "Parti")
        Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
        create_student(classroom: create_classroom, last_name: "Ailleurs")
        create_exercise_session(student: koffi, status: "completed", score_percent: 40, completed_at: 2.days.ago)
        last = create_exercise_session(student: koffi, status: "completed", score_percent: 75, completed_at: 1.day.ago)
        create_exercise_session(student: koffi, status: "completed", score_percent: 50, completed_at: 3.days.ago)
        create_exercise_session(student: koffi)
        create_exercise_session(student: create_student(classroom: create_classroom), status: "completed", score_percent: 10)

        students = overview.students

        assert_equal [ awa.public_id, koffi.public_id ], students.map(&:public_id)
        assert_equal [ "Koffi Yao", "0102030405", 75, last.public_id ],
                     students.last.to_h.values_at(:display_name, :contact, :last_score_percent, :last_session_public_id)
        assert_equal [ "Awa Bamba", awa.contact, nil, nil ],
                     students.first.to_h.values_at(:display_name, :contact, :last_score_percent, :last_session_public_id)
      end

      test "chaque élève porte la version de sa photo, en une seule requête pour la classe (ADR-0060)" do
        with_photo = attach_photo(create_student(classroom: @classroom, last_name: "Bamba"))
        create_student(classroom: @classroom, last_name: "Yao")

        versions = overview.students.map(&:photo_version)

        assert_equal [ Queries::Identity::PhotoVersions.for(user_ids: [ with_photo.id ])[with_photo.id], nil ], versions
        assert_not_nil versions.first
      end

      test "sans show_roster, aucun élève n'est lu ; une classe vide a une liste vide" do
        assert_empty overview.students

        create_student(classroom: @classroom)

        assert_nil overview(show_roster: false).students
        assert_equal 1, overview.students.size
      end

      # FU-48, UDR-0054 §3.9 : « Chercher un élève » filtre la liste de la classe par nom, sans casse ni accents.
      test "la recherche ne garde que les élèves de la classe dont le nom correspond, sans casse ni accents" do
        awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
        koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
        eloise = create_student(classroom: @classroom, first_name: "Éloïse", last_name: "Kouamé")
        create_student(classroom: create_classroom, first_name: "Awa", last_name: "Ailleurs")

        search = ->(term) { ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster: true, search: term) }

        assert_equal [ awa.public_id ], search.call("awa").students.map(&:public_id)
        assert_equal [ awa.public_id ], search.call("  AWA  BAMBA ").students.map(&:public_id)
        assert_equal [ eloise.public_id ], search.call("eloise kouame").students.map(&:public_id)
        assert_equal [ koffi.public_id ], search.call("yào").students.map(&:public_id)
        assert_empty search.call("zzz").students
        assert_empty search.call("%").students
        assert_equal 3, search.call("").students.size
        assert_equal 3, search.call(nil).students.size
        assert_nil ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster: false, search: "awa").students
      end

      test "la recherche ne filtre que les élèves, un exercice assigné n'y change rien" do
        create_assignment(classroom: @classroom, assignable: create_exercise(title: "Algèbre"))
        create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")

        result = ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster: true, search: "algèbre")

        assert_equal [ :students ], result.to_h.keys
        assert_empty result.students
      end

      test "une classe inconnue n'a pas de page" do
        assert_nil ClassroomOverviewQuery.new.call(public_id: "inconnue", show_roster: true)
      end
    end
  end
end
