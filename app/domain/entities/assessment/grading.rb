# 🧠 DOMAINE · Entities::Assessment::Grading
# Rôle : seuils pédagogiques nommés, score, note sur 20, maîtrise et palier de badge
# ADR  : 0033
module Entities
  module Assessment
    module Grading
      PASS_THRESHOLD = 50
      MASTERY_THRESHOLD = 70
      GOLD_THRESHOLD = 80
      PERFECT_THRESHOLD = 100
      BADGE_THRESHOLDS = { bronze: PASS_THRESHOLD, silver: MASTERY_THRESHOLD,
                           gold: GOLD_THRESHOLD, diamond: PERFECT_THRESHOLD }.freeze
      BADGE_ORDER = %i[bronze silver gold diamond].freeze

      # Palier le plus haut atteint, ou nil sous PASS_THRESHOLD.
      def self.badge_for(score_percent) = BADGE_ORDER.reverse.find { |level| score_percent >= BADGE_THRESHOLDS[level] }

      # Un badge ne monte que vers un palier strictement supérieur.
      def self.upgrade?(current, candidate)
        return false if candidate.nil?

        current.nil? || BADGE_ORDER.index(candidate.to_sym) > BADGE_ORDER.index(current.to_sym)
      end

      # Division entière, donc arrondi vers le bas : le Diamant exige toutes les réponses justes.
      def self.score_percent(correct:, total:) = total.zero? ? 0 : (correct * 100) / total

      def self.grade_on_20(score_percent) = (score_percent / 5.0).round

      def self.mastery_for(score_percent)
        return :acquired if score_percent >= MASTERY_THRESHOLD
        return :fragile if score_percent >= PASS_THRESHOLD

        :struggling
      end
    end
  end
end
