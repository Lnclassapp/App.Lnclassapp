# 🔌 INFRA · Queries::Assessment::ComprehensionSummaryQuery
# Rôle : résumé de la compréhension de chaque exercice assigné d'une classe : catégorie dominante (meilleurs scores) et médailles enregistrées par palier
# ADR  : 0026, 0079, XXXX-medailles-lues-a-la-cloture · UDR : 0072 (§3.4) · deux lectures (AssignmentScores, médailles), quel que soit le nombre d'assignations
module Queries
  module Assessment
    module ComprehensionSummaryQuery
      # category : la dominante des meilleurs scores, nil sous 5 élèves (pas encore lisible) ;
      # badge_counts : { bronze:, silver:, gold:, diamond: }, la médaille enregistrée (exercise_badges.level) de chaque élève qui a fait l'exercice ; sans médaille, pas de palier.
      Summary = Data.define(:category, :badge_counts)

      # → { assignment_id => Summary }, une entrée par id demandé, même sans aucun fait.
      def self.for(classroom_id:, assignment_ids:)
        scores = AssignmentScores.for(classroom_id:, assignment_ids:)
        medals = medals(assignment_ids)
        assignment_ids.to_h do |id|
          students = scores.fetch(id, [])
          levels = medals.fetch(id, {})
          [ id, summary(students.map { it.scores.max }, students.filter_map { levels[it.student_id] }) ]
        end
      end

      # → { assignment_id => { student_id => :bronze … } }, une lecture groupée des médailles de l'exercice assigné.
      def self.medals(assignment_ids)
        return {} if assignment_ids.empty?

        Orm::ClassroomAssignment.where(id: assignment_ids, assignable_type: "Exercise")
                                .joins("INNER JOIN exercise_badges ON exercise_badges.exercise_id = classroom_assignments.assignable_id")
                                .pluck("classroom_assignments.id", "exercise_badges.student_id", "exercise_badges.level")
                                .each_with_object({}) { |(id, student_id, level), by_id| (by_id[id] ||= {})[student_id] = level.to_sym }
      end
      private_class_method :medals

      def self.summary(bests, levels)
        comprehension = Entities::Assessment::Comprehension
        category = (comprehension.dominant(bests.map { comprehension.category_for(it) }.tally) if comprehension.readable?(bests.size))
        badges = Entities::Assessment::Grading::BADGE_ORDER.index_with(0)
                                                           .merge(levels.tally)
        Summary.new(category:, badge_counts: badges)
      end
      private_class_method :summary
    end
  end
end
