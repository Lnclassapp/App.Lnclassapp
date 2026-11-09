# 🔌 INFRA · Queries::Assessment::ComprehensionSummaryQuery
# Rôle : résumé de la compréhension de chaque exercice assigné d'une classe : catégorie dominante (meilleurs scores) et médailles enregistrées par palier
# ADR  : 0026, 0079, 0097 (§4.5), XXXX-medailles-lues-a-la-cloture · UDR : 0072 (§3.4) · deux lectures (AssignmentScores, médailles), quel que soit le nombre d'assignations
module Queries
  module Assessment
    module ComprehensionSummaryQuery
      # category : la dominante des meilleurs scores, nil sous 5 élèves (pas encore lisible) ;
      # badge_counts : { bronze:, silver:, gold:, diamond: }, la médaille gagnée par une session de l'assignation (Medals) de chaque élève qui l'a faite ; sans médaille, pas de palier.
      Summary = Data.define(:category, :badge_counts)

      # → { assignment_id => Summary }, une entrée par id demandé, même sans aucun fait.
      def self.for(classroom_id:, assignment_ids:)
        scores = AssignmentScores.for(classroom_id:, assignment_ids:)
        # ADR-0097 §4.5 : seules les médailles gagnées par une session de ces assignations ; une autre classe n'existe pas ici.
        medals = Medals.by_assignment(assignment_ids:)
        assignment_ids.to_h do |id|
          students = scores.fetch(id, [])
          levels = medals.fetch(id, {})
          [ id, summary(students.map { it.scores.max }, students.filter_map { levels[it.student_id] }) ]
        end
      end

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
