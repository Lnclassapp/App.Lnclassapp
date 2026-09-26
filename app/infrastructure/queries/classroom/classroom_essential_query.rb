# 🔌 INFRA · Queries::Classroom::ClassroomEssentialQuery
# Rôle : une fiche publiée vue depuis une classe (CL-12, AS-20) : ses exercices publiés, leur assignation et la réussite de la classe
# ADR  : 0026, 0035, 0048 · UDR : 0029
module Queries
  module Classroom
    class ClassroomEssentialQuery
      Row = Data.define(:classroom_public_id, :classroom_name, :course_slug, :course_name, :essential, :exercises)
      # assignment_public_id : l'assignation active à cette classe, ou nil.
      EssentialRow = Data.define(:slug, :name, :subtitle, :assignment_public_id)
      # average_score_percent : moyenne des sessions terminées des élèves présents, nil sans session ;
      # completed_students_count : élèves présents qui ont terminé au moins une session.
      ExerciseRow = Data.define(:public_id, :title, :questions_count, :assignment_public_id, :average_score_percent,
                                :completed_students_count)

      ESSENTIAL_COLUMNS = %w[essentials.id essentials.slug essentials.name essentials.subtitle courses.slug courses.name].freeze

      # → Row | nil (classe inconnue ; cours ou fiche inconnus, non publiés, ou fiche lue sous un autre cours)
      def call(classroom_public_id:, course_slug:, essential_slug:)
        classroom_id, classroom_name = Orm::Classroom.where(public_id: classroom_public_id).pick(:id, :name)
        return if classroom_id.nil?

        essential_id, slug, name, subtitle, course_slug, course_name =
          Orm::Essential.joins(:course).where(slug: essential_slug, status: "published",
                                              courses: { slug: course_slug, status: "published" }).pick(*ESSENTIAL_COLUMNS)
        return if essential_id.nil?

        exercises = Orm::Exercise.where(essential_id:, status: "published").order(:position, :id).pluck(:id, :public_id, :title)
        active = active_assignments(classroom_id, essential_id, exercises.map(&:first))
        Row.new(classroom_public_id:, classroom_name:, course_slug:, course_name:,
                essential: EssentialRow.new(slug:, name:, subtitle:, assignment_public_id: active[[ "Essential", essential_id ]]),
                exercises: exercise_rows(classroom_id, exercises, active))
      end

      private

      # { [type, id] => public_id } ; le type est lu avec l'identifiant : une fiche n'est jamais prise pour un exercice.
      def active_assignments(classroom_id, essential_id, exercise_ids)
        scope = Orm::ClassroomAssignment.where(classroom_id:, status: "active")
        scope.where(assignable_type: "Essential", assignable_id: essential_id)
             .or(scope.where(assignable_type: "Exercise", assignable_id: exercise_ids))
             .pluck(:assignable_type, :assignable_id, :public_id)
             .to_h { |type, id, public_id| [ [ type, id ], public_id ] }
      end

      def exercise_rows(classroom_id, exercises, active)
        ids = exercises.map(&:first)
        questions = Orm::Question.where(exercise_id: ids).group(:exercise_id).count
        results = results(classroom_id, ids)
        exercises.map do |id, public_id, title|
          average, students = results.fetch(id, [ nil, 0 ])
          ExerciseRow.new(public_id:, title:, questions_count: questions.fetch(id, 0), assignment_public_id: active[[ "Exercise", id ]],
                          average_score_percent: average, completed_students_count: students)
        end
      end

      # { exercise_id => [moyenne arrondie, nombre d'élèves] }, en une requête, sur les seuls élèves présents dans la classe.
      def results(classroom_id, exercise_ids)
        members = Orm::ClassroomStudent.where(classroom_id:, left_at: nil).select(:student_id)
        Orm::ExerciseSession.where(exercise_id: exercise_ids, student_id: members, status: "completed").group(:exercise_id)
                            .pluck(:exercise_id, Arel.sql("ROUND(AVG(score_percent))"), Arel.sql("COUNT(DISTINCT student_id)"))
                            .to_h { |id, average, students| [ id, [ average.to_i, students ] ] }
      end
    end
  end
end
