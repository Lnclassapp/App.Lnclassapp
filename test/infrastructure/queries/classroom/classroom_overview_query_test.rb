require "test_helper"

# CL-10 (plan boucle-pedagogique, Lot D4) : le corps de la page d'une classe. La liste des élèves seulement quand
# ReadClassroomPolicy l'accorde. Une classe avec un exercice assigné ne casse plus (CS#B8). ADR-0072 §4.6 : « Cours
# assignés » ne se lit plus, un cours ne s'assignant plus. Lot E de fonctions-espace-eleve (UDR-0062 §3.4) : les jours
# de séance de l'enseignant, les exercices assignés et leurs trois comptes, les cours du niveau de la classe.
module Queries
  module Classroom
    class ClassroomOverviewQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom
      end

      def overview(show_roster: true, **) = ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster:, **)

      test "l'aperçu porte les élèves, les jours de séance, les exercices assignés et les cours" do
        assert_equal %i[students session_days assignments courses], ClassroomOverviewQuery::Overview.members
      end

      test "jours de séance : ceux de l'enseignant pour cette classe, triés ; vides s'il n'en a pas ; nil pour l'équipe" do
        teacher = create_teacher(classrooms: [ @classroom ])
        colleague = create_teacher(classrooms: [ @classroom ])
        other = create_classroom
        Orm::TeacherClassroom.create!(teacher:, classroom: other)
        [ 4, 1 ].each { Orm::ClassroomSessionDay.create!(teacher:, classroom: @classroom, weekday: it) }
        Orm::ClassroomSessionDay.create!(teacher: colleague, classroom: @classroom, weekday: 2)
        Orm::ClassroomSessionDay.create!(teacher:, classroom: other, weekday: 6)

        assert_equal [ 1, 4 ], overview(teacher_id: teacher.id).session_days
        assert_equal [], overview(teacher_id: create_teacher(classrooms: [ @classroom ]).id).session_days
        assert_nil overview.session_days
      end

      test "exercices assignés : actifs seulement, par échéance puis du plus récent au plus ancien, sans échéance à la fin" do
        svt = create_material(name: "SVT", category: "science")
        essential = create_essential(course: create_course(material: svt))
        exercise = ->(title) { create_exercise(essential:, title:) }
        travel_to(Time.zone.local(2026, 10, 5, 9)) do
          create_assignment(classroom: @classroom, assignable: exercise.("Sans date, ancien"))
          create_assignment(classroom: @classroom, assignable: exercise.("Pour le 12"), due_on: Date.new(2026, 10, 12))
        end
        travel_to(Time.zone.local(2026, 10, 6, 9)) do
          create_assignment(classroom: @classroom, assignable: exercise.("Sans date, récent"))
          create_assignment(classroom: @classroom, assignable: exercise.("Pour le 8"), due_on: Date.new(2026, 10, 8))
          create_assignment(classroom: @classroom, assignable: exercise.("Retiré"), status: "archived")
        end
        create_assignment(classroom: create_classroom, assignable: exercise.("Autre classe"))

        rows = overview.assignments

        assert_equal [ "Pour le 8", "Pour le 12", "Sans date, récent", "Sans date, ancien" ], rows.map(&:exercise_title)
        assert_equal [ "SVT", "science", Date.new(2026, 10, 8) ], rows.first.to_h.values_at(:material_name, :material_category, :due_on)
        assert_equal Orm::ClassroomAssignment.find_by!(due_on: Date.new(2026, 10, 8)).public_id, rows.first.public_id
        assert_nil rows.last.due_on
      end

      test "les trois comptes d'un exercice assigné, lus seulement sous FollowAssignmentPolicy (show_follow_up)" do
        exercise = create_exercise
        assignment = travel_to(Time.zone.local(2026, 10, 5, 9)) do
          create_assignment(classroom: @classroom, assignable: exercise, due_on: Date.new(2026, 10, 8))
        end
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: exercise.essential))
        handed = ->(student, day) do
          create_exercise_session(student:, exercise:, status: "completed", classroom_assignment: assignment,
                                  completed_at: Time.zone.local(2026, 10, day, 10))
        end
        2.times { handed.(create_student(classroom: @classroom), 8) }
        handed.(create_student(classroom: @classroom), 9)
        create_student(classroom: @classroom)

        due, undated = overview(show_follow_up: true).assignments

        assert_equal AssignmentFollowUpQuery::Counts.new(done: 3, late: 1, pending: 1), due.counts
        assert_equal AssignmentFollowUpQuery::Counts.new(done: 0, late: 0, pending: 4), undated.counts
        assert_equal [ nil, nil ], overview.assignments.map(&:counts)
      end

      test "cours : publiés, du niveau de la classe, sans série ou de sa série, de la matière de l'enseignant ; toutes pour l'équipe" do
        tle = create_level(name: "Tle")
        d = create_series(name: "D")
        @classroom = create_classroom(level: tle, series: d)
        svt = create_material(name: "SVT", category: "science")
        maths = create_material(name: "Mathématiques", category: "science")
        teacher = create_teacher(material: svt, classrooms: [ @classroom ])
        genetics = create_course(level: tle, series: d, material: svt, name: "Génétique", subtitle: "Hérédité")
        create_essential(course: genetics)
        create_essential(course: genetics)
        create_essential(course: genetics, status: "draft")
        create_course(level: tle, material: svt, name: "Botanique")
        create_course(level: tle, material: maths, name: "Fonctions")
        create_course(level: tle, series: create_series(name: "C"), material: svt, name: "Série C")
        create_course(level: create_level(name: "1ère"), material: svt, name: "Autre niveau")
        create_course(level: tle, series: d, material: svt, name: "Brouillon", status: "draft")

        courses = overview(teacher_id: teacher.id).courses

        assert_equal %w[Botanique Génétique], courses.map(&:name)
        assert_equal ClassroomOverviewQuery::CourseRow.new(slug: genetics.slug, name: "Génétique", subtitle: "Hérédité", level_name: "Tle",
                                                           series_name: "D", material_name: "SVT", material_category: "science",
                                                           essentials_count: 2), courses.last
        assert_equal 0, courses.first.essentials_count
        assert_equal %w[Fonctions Botanique Génétique], overview.courses.map(&:name)
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

        assert_empty result.students
        assert_equal [ "Algèbre" ], result.assignments.map(&:exercise_title)
      end

      test "une classe inconnue n'a pas de page" do
        assert_nil ClassroomOverviewQuery.new.call(public_id: "inconnue", show_roster: true)
      end
    end
  end
end
