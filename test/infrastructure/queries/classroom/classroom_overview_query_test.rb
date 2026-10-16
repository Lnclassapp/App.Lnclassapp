require "test_helper"

# CL-10 (plan boucle-pedagogique, Lot D4) : le corps de la page d'une classe. La liste des élèves seulement quand
# ReadClassroomPolicy l'accorde. Une classe avec un exercice assigné ne casse plus (CS#B8). ADR-0072 §4.6 : « Cours
# assignés » ne se lit plus, un cours ne s'assignant plus. Lot E de fonctions-espace-eleve (UDR-0062 §3.4) : les jours
# de séance de l'enseignant, les exercices assignés et leurs trois comptes, les cours du niveau de la classe.
module Queries
  module Classroom
    class ClassroomOverviewQueryTest < ActiveSupport::TestCase
      TODAY = Date.new(2026, 10, 15)

      setup do
        @classroom = create_classroom
      end

      def overview(show_roster: true, **) = ClassroomOverviewQuery.new.call(public_id: @classroom.public_id, show_roster:, **)

      test "l'aperçu porte les élèves et leurs nouveaux, les jours de séance, les exercices assignés et les cours" do
        assert_equal %i[students students_total grade_group grade_counts new_students_count session_days assignments courses],
                     ClassroomOverviewQuery::Overview.members
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

      # rapports-exercices, Lot A (ADR-0079, UDR-0072 §3.4) : badges et cercle au bord bas, sous la même condition que les comptes.
      test "le résumé de compréhension d'un exercice assigné, lu seulement sous FollowAssignmentPolicy, comme les comptes" do
        exercise = create_exercise
        create_assignment(classroom: @classroom, assignable: create_exercise(essential: exercise.essential))
        assignment = create_assignment(classroom: @classroom, assignable: exercise)
        [ 100, 85, 72, 65, 40, 30 ].each do |score_percent|
          create_exercise_session(student: create_student(classroom: @classroom), exercise:, status: "completed",
                                  score_percent:, classroom_assignment: assignment)
        end

        done, nobody = overview(show_follow_up: true).assignments
        summary = Queries::Assessment::ComprehensionSummaryQuery::Summary

        assert_equal assignment.public_id, done.public_id
        assert_equal summary.new(category: :acquired, badge_counts: { bronze: 1, silver: 1, gold: 1, diamond: 1 }), done.comprehension
        assert_equal summary.new(category: nil, badge_counts: { bronze: 0, silver: 0, gold: 0, diamond: 0 }), nobody.comprehension
        assert_equal AssignmentFollowUpQuery::Counts.new(done: 6, late: 0, pending: 0), done.counts
        assert_equal [ nil, nil ], overview.assignments.map(&:comprehension)
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

      test "la liste nomme les élèves présents, avec leur numéro masqué et leur dernier score" do
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
        assert_equal [ "Koffi Yao", "01 •• •• •• 05", 75, last.public_id ],
                     students.last.to_h.values_at(:display_name, :contact, :last_score_percent, :last_session_public_id)
        assert_equal [ "Awa Bamba", Entities::Identity::Contact.mask(awa.contact), nil, nil ],
                     students.first.to_h.values_at(:display_name, :contact, :last_score_percent, :last_session_public_id)
      end

      # IE-22 (ADR-0083 §4.4 bis, memo Q23) : quel que soit le lecteur (enseignant, quelle que soit sa voie, ou équipe),
      # le numéro complet d'un élève ne sort jamais de la requête.
      test "IE-22 : le numéro d'un élève sort masqué de la requête, pour tout lecteur, jamais en entier" do
        create_student(classroom: @classroom, contact: "0701020304")

        [ create_teacher(classrooms: [ @classroom ]).id, nil ].each do |teacher_id|
          row = overview(teacher_id:).students.sole

          assert_equal "07 •• •• •• 04", row.contact, teacher_id.inspect
          assert_not_includes row.to_h.values.join(" "), "0701020304"
        end
      end

      test "chaque élève porte la version de sa photo, en une seule requête pour la classe (ADR-0060)" do
        with_photo = attach_photo(create_student(classroom: @classroom, last_name: "Bamba", joined_at: 1.month.ago))
        create_student(classroom: @classroom, last_name: "Yao", joined_at: 1.month.ago)

        versions = overview.students.map(&:photo_version)

        assert_equal [ Queries::Identity::PhotoVersions.for(user_ids: [ with_photo.id ])[with_photo.id], nil ], versions
        assert_not_nil versions.first
      end

      # IL-13 (ADR-0085 §4.4, UDR-0081 §3.7) : « nouveau » pendant 7 jours après joined_at, calcul de lecture ; la voie
      # d'arrivée sur chaque ligne ; les nouveaux d'abord, du plus récent au plus ancien, les autres par nom.
      test "IL-13 : nouveaux arrivés en tête, du plus récent au plus ancien, avec leur voie ; les autres par nom" do
        travel_to(Time.zone.local(2026, 10, 7, 9)) do
          koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_via: "standard",
                                 joined_at: 2.days.ago)
          awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", joined_via: "link",
                               joined_at: 10.days.ago)
          zoe = create_student(classroom: @classroom, first_name: "Zoé", last_name: "Zran", joined_via: "link",
                               joined_at: 1.hour.ago)
          ali = create_student(classroom: @classroom, first_name: "Ali", last_name: "Cissé", joined_via: "code",
                               joined_at: 1.year.ago)
          edge = create_student(classroom: @classroom, first_name: "Éva", last_name: "Diallo", joined_via: "standard",
                                joined_at: 7.days.ago)
          left = create_student(classroom: @classroom, joined_at: 1.day.ago)
          Orm::ClassroomStudent.where(student: left).update_all(left_at: Time.current)
          create_student(classroom: create_classroom, joined_at: 1.day.ago)

          students = overview.students

          assert_equal [ zoe, koffi, awa, ali, edge ].map(&:public_id), students.map(&:public_id)
          assert_equal [ true, true, false, false, false ], students.map(&:newcomer)
          assert_equal %w[link standard link code standard], students.map(&:joined_via)
          assert_equal 2, overview.new_students_count
          assert_nil overview(show_roster: false).new_students_count
        end
      end

      test "IL-13 : le compte des nouveaux est celui de la classe, pas celui de la recherche" do
        create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba", joined_at: 1.day.ago)
        create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao", joined_at: 2.days.ago)

        result = overview(search: "awa")

        assert_equal 1, result.students.size
        assert_equal 2, result.new_students_count
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

      # CA-16 (accueil-eleve, ADR-0089 §4.2, UDR-0084 §3.7) : « Fait seul (7 j) » compte les sessions terminées, standard,
      # sans assignation, commencées dans les 7 derniers jours d'Abidjan, aujourd'hui compris.
      def practise(student, days_ago, hour: 10, **)
        create_exercise_session(student:, status: "completed", started_at: (TODAY - days_ago).in_time_zone + hour.hours, **)
      end

      test "CA-16 : un exercice non donné terminé il y a 3 jours compte 1 ; il y a 8 jours, 0" do
        recent = create_student(classroom: @classroom, last_name: "Bamba", joined_at: 1.month.ago)
        old = create_student(classroom: @classroom, last_name: "Yao", joined_at: 1.month.ago)
        practise(recent, 3)
        practise(old, 8)

        assert_equal [ 1, 0 ], overview(today: TODAY).students.map(&:self_practice_count)
      end

      test "CA-16 : la fenêtre va du 6e jour avant, à minuit d'Abidjan, à la fin d'aujourd'hui" do
        student = create_student(classroom: @classroom)
        practise(student, 6, hour: 0)
        practise(student, 0, hour: 23)
        practise(student, 7, hour: 23)
        practise(student, -1, hour: 0)

        assert_equal 2, overview(today: TODAY).students.sole.self_practice_count
      end

      test "CA-16 : une session assignée, une remédiation, une session commencée ou celle d'un autre élève ne comptent pas" do
        student = create_student(classroom: @classroom)
        exercise = create_exercise
        assignment = create_assignment(classroom: @classroom, assignable: exercise)
        practise(student, 1, exercise:, classroom_assignment: assignment)
        source = practise(student, 20, score_percent: 40)
        practise(student, 1, gap: create_gap(student:, source_session: source))
        create_exercise_session(student:, started_at: Time.zone.local(2026, 10, 14, 10))
        practise(create_student(classroom: create_classroom), 1)
        practise(student, 2)

        assert_equal 1, overview(today: TODAY).students.sole.self_practice_count
      end

      test "CA-16 : sans show_roster, le compte n'est pas lu ; par défaut, aujourd'hui est la date d'Abidjan" do
        student = create_student(classroom: @classroom)
        practise(student, 3)

        assert_nil overview(show_roster: false, today: TODAY).students
        travel_to(Time.zone.local(2026, 10, 15, 12)) { assert_equal 1, overview.students.sole.self_practice_count }
        travel_to(Time.zone.local(2026, 10, 22, 12)) { assert_equal 0, overview.students.sole.self_practice_count }
      end

      test "CA-16 : le compte de toute la liste se lit en une requête, quel que soit le nombre d'élèves" do
        practise(create_student(classroom: @classroom), 1)
        few = count_queries { overview(today: TODAY) }
        3.times { practise(create_student(classroom: @classroom), 2) }

        assert_equal few, count_queries { overview(today: TODAY) }
        assert_equal [ 1, 1, 1, 1 ], overview(today: TODAY).students.map(&:self_practice_count)
      end

      # rapports-de-classe, Lot B (CL-15 ; ADR-0097 §4.7, UDR-0108) : dans un groupe, trente élèves, puis trente de plus,
      # cumulativement. Sans exercice fait, tous sont dans « Pas encore de note ».
      def roster_of(count, last_name: "Élève", joined_at: 1.month.ago)
        Array.new(count) { |index| create_student(classroom: @classroom, first_name: format("N%02d", index), last_name:, joined_at:) }
      end

      test "CL-15 : trente élèves par page, cumulés ; students_total compte toute la classe" do
        roster_of(65)

        assert_equal 30, ClassroomOverviewQuery::PER_PAGE
        assert_equal "none", overview.grade_group
        assert_equal [ 30, 65 ], overview.then { [ it.students.size, it.students_total ] }
        assert_equal [ 60, 65 ], overview(page: 2).then { [ it.students.size, it.students_total ] }
        assert_equal [ 65, 65 ], overview(page: 3).then { [ it.students.size, it.students_total ] }
        assert_equal [ 65, 65 ], overview(page: 9).then { [ it.students.size, it.students_total ] }
        assert_equal overview.students.map(&:public_id), overview(page: 2).students.first(30).map(&:public_id)
      end

      test "CL-15 : une page nulle, négative ou qui n'est pas un entier vaut la première" do
        roster_of(31)

        [ 0, -1, nil, "2", 1.5 ].each { assert_equal 30, overview(page: it).students.size, it.inspect }
      end

      test "CL-15 : les nouveaux restent en tête de la première page" do
        roster_of(63)
        newcomers = Array.new(2) { |index| create_student(classroom: @classroom, last_name: "Arrivé#{index}", joined_at: (3 + index).days.ago) }

        assert_equal newcomers.map(&:public_id), overview.students.first(2).map(&:public_id)
        assert_equal 2, overview.new_students_count
      end

      test "CL-15 : avec une recherche, le total est celui des élèves qui y répondent" do
        roster_of(40, last_name: "Koné")
        roster_of(5, last_name: "Bamba")

        assert_equal [ 30, 40 ], overview(search: "kon").then { [ it.students.size, it.students_total ] }
        assert_equal [ 40, 40 ], overview(search: "kon", page: 2).then { [ it.students.size, it.students_total ] }
        assert_equal [ nil, nil, nil ], overview(show_roster: false).to_h.values_at(:students_total, :grade_group, :grade_counts)
      end

      # Décision du porteur du 2026-10-16 (UDR-0108 amendée) : la liste se découpe par note sur 20, la moyenne des meilleurs
      # scores aux exercices assignés à la classe ; trente par trente dans un groupe.
      def graded(scores, first_name: "Élève")
        create_student(classroom: @classroom, first_name:, last_name: "N#{factory_sequence}", joined_at: 1.month.ago).tap do |student|
          scores.each_with_index do |score, index|
            @assignments[index] ||= create_assignment(classroom: @classroom, assignable: create_exercise)
            exercise = Orm::Exercise.find(@assignments[index].assignable_id)
            create_exercise_session(student:, exercise:, status: "completed", score_percent: score,
                                    classroom_assignment: @assignments[index])
          end
        end
      end

      test "CL-15 : la note d'un élève est la moyenne sur 20 de ses meilleurs scores aux exercices assignés à la classe" do
        @assignments = []
        awa = graded([ 40, 60 ], first_name: "Awa")
        exercise = Orm::Exercise.find(@assignments[0].assignable_id)
        create_exercise_session(student: awa, exercise:, status: "completed", score_percent: 20, classroom_assignment: @assignments[0])
        create_exercise_session(student: awa, exercise:, classroom_assignment: @assignments[0])
        create_exercise_session(student: awa, status: "completed", score_percent: 100)
        archived = create_assignment(classroom: @classroom, assignable: create_exercise, status: "archived")
        create_exercise_session(student: awa, exercise: Orm::Exercise.find(archived.assignable_id), status: "completed",
                                score_percent: 100, classroom_assignment: archived)
        elsewhere = create_assignment(classroom: create_classroom, assignable: exercise)
        create_exercise_session(student: awa, exercise:, status: "completed", score_percent: 100, classroom_assignment: elsewhere)
        gap = create_gap(student: awa, essential: Orm::Exercise.find(@assignments[1].assignable_id).essential)
        create_exercise_session(student: awa, exercise: Orm::Exercise.find(@assignments[1].assignable_id), status: "completed",
                                score_percent: 80, classroom_assignment: @assignments[1], gap:)

        # (40 + 80) / 2 = 60 % : 12 sur 20 — la remédiation sur l'exercice assigné compte, rien d'autre.
        assert_equal [ [ awa.public_id, 12 ] ], overview(note: "11-15").students.map { [ it.public_id, it.grade ] }
      end

      test "CL-15 : un groupe par note, le premier non vide depuis 0–10 par défaut ; le compte de chaque groupe" do
        @assignments = []
        good = Array.new(2) { graded([ 60 ]) }
        best = graded([ 95 ])
        3.times { create_student(classroom: @classroom) }

        result = overview

        assert_equal({ "0-10" => 0, "11-15" => 2, "16-20" => 1, "none" => 3 }, result.grade_counts)
        assert_equal "11-15", result.grade_group
        assert_equal good.map(&:public_id).sort, result.students.map(&:public_id).sort
        assert_equal [ 2, [ 12, 12 ] ], [ result.students_total, result.students.map(&:grade) ]
        assert_equal [ best.public_id ], overview(note: "16-20").students.map(&:public_id)
        assert_equal [ 3, [ nil ] ], overview(note: "none").then { [ it.students_total, it.students.map(&:grade).uniq ] }
        assert_equal [ "0-10", [] ], overview(note: "0-10").then { [ it.grade_group, it.students ] }
        assert_equal "11-15", overview(note: "12-14").grade_group
      end

      test "CL-15 : la recherche porte sur toute la classe, quel que soit le groupe" do
        @assignments = []
        graded([ 30 ], first_name: "Koné")
        graded([ 95 ], first_name: "Koné")
        create_student(classroom: @classroom, first_name: "Koné")
        graded([ 60 ], first_name: "Awa")

        result = overview(search: "kon", note: "11-15")

        assert_nil result.grade_group
        assert_equal [ 3, 3 ], [ result.students.size, result.students_total ]
        assert_equal({ "0-10" => 1, "11-15" => 1, "16-20" => 1, "none" => 1 }, result.grade_counts)
      end

      test "CL-15 : le nombre de requêtes ne dépend ni de la page, ni du groupe, ni de l'effectif" do
        @assignments = []
        roster_of(31)
        first = count_queries { overview(today: TODAY) }
        graded([ 50, 70 ])
        graded([ 90 ])

        assert_equal first, count_queries { overview(today: TODAY, page: 2) }
        assert_equal first, count_queries { overview(today: TODAY, note: "11-15") }
      end

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
