# 🔌 INFRA · Queries::Classroom::ClassroomEssentialQuery
# Rôle : une fiche publiée vue depuis une classe (CL-12, AS-20) : ses exercices publiés, leur assignation, leur échéance et la
#        réussite de la classe ; et si l'enseignant doit encore donner ses jours de séance (UDR-0062 §3.4)
# ADR  : 0026, 0035, 0048, 0072 · UDR : 0029, 0062
module Queries
  module Classroom
    class ClassroomEssentialQuery
      # needs_session_days : l'acteur enseigne la classe et n'a pas renseigné ses jours ; « Assigner » ouvre alors la modale.
      Row = Data.define(:classroom_public_id, :classroom_name, :course_slug, :course_name, :essential, :exercises,
                        :needs_session_days)
      # ADR-0072 §4.1 : la fiche ne s'assigne plus ; seuls ses exercices portent une assignation.
      EssentialRow = Data.define(:slug, :name, :subtitle)
      # Décision du porteur (2026-09-27) : la réussite est la part des élèves en réussite, pas une moyenne de scores.
      # completed_students_count : élèves présents qui ont terminé au moins une session ;
      # passed_students_count : parmi eux, ceux dont le meilleur score atteint PASS_THRESHOLD ;
      # success_percent : leur part arrondie, nil sans session.
      # due_on : l'échéance figée de l'assignation active (ADR-0072 §4.3), nil sans assignation ou sans jours.
      ExerciseRow = Data.define(:public_id, :title, :questions_count, :assignment_public_id, :due_on, :success_percent,
                                :passed_students_count, :completed_students_count)

      ESSENTIAL_COLUMNS = %w[essentials.id essentials.slug essentials.name essentials.subtitle courses.slug courses.name].freeze

      # teacher_id : l'enseignant connecté, nil pour l'équipe (elle n'a pas de jours de séance).
      # → Row | nil (classe inconnue ; cours ou fiche inconnus, non publiés, ou fiche lue sous un autre cours)
      def call(classroom_public_id:, course_slug:, essential_slug:, teacher_id: nil)
        classroom_id, classroom_name = Orm::Classroom.where(public_id: classroom_public_id).pick(:id, :name)
        return if classroom_id.nil?

        essential_id, slug, name, subtitle, course_slug, course_name =
          Orm::Essential.joins(:course).where(slug: essential_slug, status: "published",
                                              courses: { slug: course_slug, status: "published" }).pick(*ESSENTIAL_COLUMNS)
        return if essential_id.nil?

        exercises = Orm::Exercise.where(essential_id:, status: "published").order(:position, :id).pluck(:id, :public_id, :title)
        active = active_assignments(classroom_id, exercises.map(&:first))
        Row.new(classroom_public_id:, classroom_name:, course_slug:, course_name:,
                essential: EssentialRow.new(slug:, name:, subtitle:), exercises: exercise_rows(classroom_id, exercises, active),
                needs_session_days: needs_session_days?(classroom_id, teacher_id))
      end

      private

      # Une requête : la déclaration existe, et aucun jour n'est renseigné pour elle (ADR-0072 §4.2).
      def needs_session_days?(classroom_id, teacher_id)
        return false if teacher_id.nil?

        Orm::TeacherClassroom.where(teacher_id:, classroom_id:)
                             .where.not(Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:).arel.exists).exists?
      end

      # { exercise_id => [public_id, due_on] } de l'assignation active de chaque exercice à cette classe.
      def active_assignments(classroom_id, exercise_ids)
        Orm::ClassroomAssignment.where(classroom_id:, status: "active", assignable_type: "Exercise", assignable_id: exercise_ids)
                                .pluck(:assignable_id, :public_id, :due_on).to_h { |id, public_id, due_on| [ id, [ public_id, due_on ] ] }
      end

      def exercise_rows(classroom_id, exercises, active)
        ids = exercises.map(&:first)
        questions = Orm::Question.where(exercise_id: ids).group(:exercise_id).count
        results = results(classroom_id, ids)
        exercises.map do |id, public_id, title|
          assignment_public_id, due_on = active[id]
          ExerciseRow.new(public_id:, title:, questions_count: questions.fetch(id, 0), assignment_public_id:, due_on:,
                          **success(results.fetch(id, [])))
        end
      end

      def success(best_scores)
        passed = best_scores.count { it >= Entities::Assessment::Grading::PASS_THRESHOLD }
        percent = (passed * 100.0 / best_scores.size).round unless best_scores.empty?
        { success_percent: percent, passed_students_count: passed, completed_students_count: best_scores.size }
      end

      # { exercise_id => [meilleur score de chaque élève] }, en une requête, sur les seuls élèves présents dans la classe.
      def results(classroom_id, exercise_ids)
        members = Orm::ClassroomStudent.where(classroom_id:, left_at: nil).select(:student_id)
        Orm::ExerciseSession.where(exercise_id: exercise_ids, student_id: members, status: "completed")
                            .group(:exercise_id, :student_id).pluck(:exercise_id, Arel.sql("MAX(score_percent)"))
                            .group_by(&:first).transform_values { |rows| rows.map(&:last) }
      end
    end
  end
end
