require "test_helper"

# CL-10 (plan boucle-pedagogique, Lot D4) : le corps de la page d'une classe. Les cours assignés, actifs et publiés ; la liste
# des élèves seulement quand ReadClassroomPolicy l'accorde. Une classe avec un exercice assigné ne casse plus (CS#B8).
module Queries
  module Classroom
    class ClassroomOverviewQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom
      end

      def overview(show_roster: true) = ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster:)

      test "les cours assignés sont les actifs et publiés, avec leurs libellés et leurs fiches publiées, par nom" do
        genetics = create_course(name: "Génétique", subtitle: "De l'ADN aux caractères", level: create_level(name: "Tle"),
                                 series: create_series(name: "D"), material: create_material(name: "SVT", category: "science"))
        create_essential(course: genetics)
        create_essential(course: genetics)
        create_essential(course: genetics, status: "draft")
        algebra = create_course(name: "Algèbre")
        create_assignment(classroom: @classroom, assignable: genetics)
        create_assignment(classroom: @classroom, assignable: algebra)
        create_assignment(classroom: @classroom, assignable: create_course(name: "Retiré"), status: "archived")
        create_assignment(classroom: @classroom, assignable: create_course(name: "Archivé", status: "archived"))
        create_assignment(classroom: create_classroom, assignable: create_course(name: "Autre classe"))

        courses = overview.courses

        assert_equal [ "Algèbre", "Génétique" ], courses.map(&:name)
        assert_equal [ genetics.slug, "Génétique", "De l'ADN aux caractères", "Tle", "D", "SVT", "science", 2 ],
                     courses.last.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                                 :material_category, :essentials_count)
        assert_equal [ nil, 0 ], courses.first.to_h.values_at(:series_name, :essentials_count)
      end

      test "une fiche ou un exercice assigné n'est pas un cours, et ne casse rien (CS#B8)" do
        exercise = create_exercise
        create_assignment(classroom: @classroom, assignable: exercise)
        create_assignment(classroom: @classroom, assignable: exercise.essential)

        assert_empty overview.courses
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

      test "une classe inconnue n'a pas de page" do
        assert_nil ClassroomOverviewQuery.new.call(public_id: "inconnue", show_roster: true)
      end
    end
  end
end
