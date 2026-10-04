# 🔌 INFRA · Queries::Assessment::ComprehensionSummaryQuery
# Rôle : résumé de la compréhension de chaque exercice assigné d'une classe : catégorie dominante et badges par palier
# ADR  : 0026, 0079 · UDR : 0072 (§3.4) · une seule lecture, celle d'AssignmentScores, quel que soit le nombre d'assignations
module Queries
  module Assessment
    module ComprehensionSummaryQuery
      # category : la dominante des meilleurs scores, nil sous 5 élèves (pas encore lisible) ;
      # badge_counts : { bronze:, silver:, gold:, diamond: }, Grading.badge_for(meilleur score) ; sous 50, pas de palier.
      Summary = Data.define(:category, :badge_counts)

      # → { assignment_id => Summary }, une entrée par id demandé, même sans aucun fait.
      def self.for(classroom_id:, assignment_ids:)
        scores = AssignmentScores.for(classroom_id:, assignment_ids:)
        assignment_ids.to_h { |id| [ id, summary(scores.fetch(id, []).map { it.scores.max }) ] }
      end

      def self.summary(bests)
        comprehension = Entities::Assessment::Comprehension
        category = (comprehension.dominant(bests.map { comprehension.category_for(it) }.tally) if comprehension.readable?(bests.size))
        badges = Entities::Assessment::Grading::BADGE_ORDER.index_with(0)
                                                           .merge(bests.filter_map { Entities::Assessment::Grading.badge_for(it) }.tally)
        Summary.new(category:, badge_counts: badges)
      end
      private_class_method :summary
    end
  end
end
