require "test_helper"

module Queries
  module Classroom
    # CL-12, AS-20 : l'ancien écran levait PG::UndefinedColumn (exercise_id) dès que la fiche avait un exercice. Ici, seules
    # les assignations actives d'exercice se lisent (ADR-0072 §4.1 : la fiche ne s'assigne plus), et aucun exercice non
    # publié n'est proposé.
    class ClassroomEssentialQueryTest < ActiveSupport::TestCase
      setup do
        @classroom = create_classroom(name: "Tle D 1")
        @course = create_course(name: "Génétique et évolution")
        @essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
        @first = create_exercise(essential: @essential, title: "Les phases", questions: 3)
        @second = create_exercise(essential: @essential, title: "Le brassage", questions: 1)
      end

      def query(essential_slug: @essential.slug, course_slug: @course.slug, classroom_public_id: @classroom.public_id, teacher_id: nil)
        ClassroomEssentialQuery.new.call(classroom_public_id:, course_slug:, essential_slug:, teacher_id:)
      end

      test "la classe, le cours, la fiche et ses exercices publiés dans l'ordre, sans assignation ni résultat" do
        create_exercise(essential: @essential, title: "Brouillon", status: "draft")
        create_exercise(essential: @essential, title: "Archivé", status: "archived")

        row = query

        assert_equal [ @classroom.public_id, "Tle D 1" ], [ row.classroom_public_id, row.classroom_name ]
        assert_equal [ @course.slug, "Génétique et évolution" ], [ row.course_slug, row.course_name ]
        assert_equal [ @essential.slug, "La méiose", "Deux divisions" ], row.essential.to_h.values_at(:slug, :name, :subtitle)
        assert_not_includes ClassroomEssentialQuery::EssentialRow.members, :assignment_public_id
        assert_equal [ [ @first.public_id, "Les phases", 3, nil, nil, 0, 0 ], [ @second.public_id, "Le brassage", 1, nil, nil, 0, 0 ] ],
                     row.exercises.map { it.to_h.values_at(:public_id, :title, :questions_count, :assignment_public_id,
                                                           :success_percent, :passed_students_count, :completed_students_count) }
      end

      test "l'assignation active de chaque exercice, jamais une ligne archivée ni celle d'une autre classe" do
        create_assignment(classroom: @classroom, assignable: @first, status: "archived")
        first_assignment = create_assignment(classroom: @classroom, assignable: @first)
        create_assignment(classroom: @classroom, assignable: @second, status: "archived")
        create_assignment(classroom: create_classroom, assignable: @second)
        # L'exercice d'une autre fiche, assigné à la classe, ne fait pas passer ceux-ci pour assignés.
        create_assignment(classroom: @classroom, assignable: create_exercise)

        row = query

        assert_equal [ first_assignment.public_id, nil ], row.exercises.map(&:assignment_public_id)
      end

      # ADR-0072 §4.3 : l'échéance figée de l'assignation active, nil sans jours ou sans assignation.
      test "l'échéance de l'assignation active de chaque exercice" do
        create_assignment(classroom: @classroom, assignable: @first, due_on: Time.zone.today + 3)
        create_assignment(classroom: @classroom, assignable: @second, status: "archived", due_on: Time.zone.today + 1)

        assert_equal [ Time.zone.today + 3, nil ], query.exercises.map(&:due_on)
      end

      # UDR-0062 §3.4 : la modale des jours s'ouvre pour l'enseignant de la classe qui ne les a pas renseignés ;
      # jamais pour l'équipe ni pour un acteur sans teacher_id, jamais une fois ses jours connus.
      test "needs_session_days : vrai pour l'enseignant de la classe sans jours, faux sinon" do
        teacher = create_teacher(classrooms: [ @classroom ])
        colleague = create_teacher(classrooms: [ @classroom ])
        Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: colleague.id, classroom_id: @classroom.id,
                                                                    weekdays: [ 2 ], at: Time.current)

        assert query(teacher_id: teacher.id).needs_session_days
        assert_not query(teacher_id: colleague.id).needs_session_days
        assert_not query(teacher_id: create_teacher.id).needs_session_days
        assert_not query.needs_session_days
      end

      test "la réussite de la classe : part de ses élèves présents dont le meilleur score atteint le seuil, par exercice" do
        alice = create_student(classroom: @classroom)
        bruno = create_student(classroom: @classroom)
        gone = create_student(classroom: @classroom)
        Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
        create_exercise_session(student: alice, exercise: @first, status: "completed", score_percent: 40)
        create_exercise_session(student: alice, exercise: @first, status: "completed", score_percent: 80)
        create_exercise_session(student: bruno, exercise: @first, status: "completed", score_percent: 49)
        create_exercise_session(student: bruno, exercise: @first, status: "started")
        create_exercise_session(student: bruno, exercise: @second, status: "started")
        create_exercise_session(student: gone, exercise: @second, status: "completed", score_percent: 10)
        create_exercise_session(student: create_student, exercise: @second, status: "completed", score_percent: 10)

        row = query

        # Alice réussit par son meilleur score (80), Bruno non (49) ; un élève parti ou d'une autre classe ne compte pas.
        assert_equal [ [ 50, 1, 2 ], [ nil, 0, 0 ] ],
                     row.exercises.map { [ it.success_percent, it.passed_students_count, it.completed_students_count ] }
      end

      # ADR-0036, amendement (2), lot R2 : la suppression réelle, par le use case câblé comme le contrôleur de l'équipe.
      def delete_account(student)
        team = create_team_member(team_role: "admin")
        UseCases::Identity::AnonymizeUser.new(
          users: Repositories::Identity::UserRepository.new, sessions: Repositories::Identity::SessionRepository.new,
          second_factors: Repositories::Identity::SecondFactorRepository.new,
          pin_recoveries: Repositories::Identity::PinRecoveryRepository.new,
          login_attempts: Repositories::Identity::LoginAttemptRepository.new,
          memberships: Repositories::Classroom::MembershipRepository.new, photos: Repositories::Identity::ProfilePhotoStore.new,
          audit_log: Repositories::Identity::AuditLogRepository.new, learning_data: Repositories::Assessment::LearningDataEraser.new,
          transaction: Repositories::Shared::Transaction.new, policy: Policies::Identity::DeleteUserPolicy.new, clock: Time.zone,
          deletion_requests: Repositories::Identity::DeletionRequestRepository.new
        ).call(actor: Entities::Identity::Actor.new(user_id: team.id, role: :team, team_role: "admin"),
               target_public_id: student.public_id, dto: Dtos::Identity::DeletionRequestInput.new(requested_on: Date.current.iso8601))
      end

      def success = query.exercises.first.to_h.values_at(:success_percent, :passed_students_count, :completed_students_count)

      test "la réussite de la classe avant et après la suppression d'un compte élève : il n'y compte plus" do
        alice = create_student(classroom: @classroom)
        bruno = create_student(classroom: @classroom)
        awa = create_student(classroom: @classroom)
        create_exercise_session(student: alice, exercise: @first, status: "completed", score_percent: 80)
        create_exercise_session(student: bruno, exercise: @first, status: "completed", score_percent: 30)
        create_badge(student: awa, exercise: @first, session: create_exercise_session(student: awa, exercise: @first,
                                                                                    status: "completed", score_percent: 100))

        assert_equal [ 67, 2, 3 ], success
        assert delete_account(awa).success?

        assert_equal [ 50, 1, 2 ], success
        assert_not Orm::ExerciseSession.exists?(student_id: awa.id)
      end

      test "une fiche sans exercice publié" do
        essential = create_essential(course: @course)

        assert_empty query(essential_slug: essential.slug).exercises
      end

      test "une classe, un cours ou une fiche inconnus, non publiés, ou une fiche lue sous un autre cours : nil" do
        draft_course = create_course(status: "draft")
        draft_course_essential = create_essential(course: draft_course)
        draft = create_essential(course: @course, status: "draft")
        archived = create_essential(course: @course, status: "archived")
        elsewhere = create_essential

        assert_nil query(classroom_public_id: "inconnue")
        assert_nil query(course_slug: "inconnu")
        assert_nil query(course_slug: draft_course.slug, essential_slug: draft_course_essential.slug)
        [ "inconnue", draft.slug, archived.slug, elsewhere.slug ].each do |essential_slug|
          assert_nil query(essential_slug:), essential_slug
        end
      end
    end
  end
end
