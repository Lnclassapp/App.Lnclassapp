# 🧠 DOMAINE · Entities::Assessment::Grading
# Rôle : seuils pédagogiques nommés, score, note sur 20, maîtrise et palier de badge, tous lus sur la note affichée
# ADR  : 0033, 0043, 0106
module Entities
  module Assessment
    module Grading
      PASS_THRESHOLD = 50
      MASTERY_THRESHOLD = 70
      # ADR-0043, amendement du 2026-09-27 : une lacune n'est résolue qu'à partir de ce score (décision du porteur).
      REMEDIATION_THRESHOLD = 75
      GOLD_THRESHOLD = 80
      PERFECT_THRESHOLD = 100
      BADGE_THRESHOLDS = { bronze: PASS_THRESHOLD, silver: MASTERY_THRESHOLD,
                           gold: GOLD_THRESHOLD, diamond: PERFECT_THRESHOLD }.freeze
      BADGE_ORDER = %i[bronze silver gold diamond].freeze
      # Les paliers qui se lisent sur la note affichée, du plus haut au plus bas : le Diamant n'en fait pas partie.
      GRADED_LEVELS = %i[gold silver bronze].freeze

      # Décision du porteur (2026-10-19, ADR-0106) : ce que l'élève lit fait foi. Un score atteint un seuil quand sa note
      # sur 20 (grade_on_20, le seul endroit de l'arrondi) atteint celle du seuil : 68 % s'affiche 14/20 et atteint 70.
      # Toute règle « réussi / acquis / à revoir » passe par ici ; aucune ne compare le pourcentage brut à un seuil.
      def self.reaches?(score_percent, threshold) = grade_on_20(score_percent) >= grade_on_20(threshold)

      # Le sans-faute est un fait, pas une note : score_percent est arrondi vers le bas, il ne vaut 100 que si toutes les
      # réponses sont justes. 98 % s'affiche 20/20 mais n'est pas un sans-faute.
      def self.perfect?(score_percent) = score_percent >= PERFECT_THRESHOLD

      # Palier le plus haut atteint, ou nil sous la note de PASS_THRESHOLD.
      def self.badge_for(score_percent)
        return :diamond if perfect?(score_percent)

        GRADED_LEVELS.find { |level| reaches?(score_percent, BADGE_THRESHOLDS[level]) }
      end

      # Un badge ne monte que vers un palier strictement supérieur.
      def self.upgrade?(current, candidate)
        return false if candidate.nil?

        current.nil? || BADGE_ORDER.index(candidate.to_sym) > BADGE_ORDER.index(current.to_sym)
      end

      # Division entière, donc arrondi vers le bas : le Diamant exige toutes les réponses justes.
      def self.score_percent(correct:, total:)
        total.zero? ? 0 : (correct * 100) / total
      end

      def self.grade_on_20(score_percent) = (score_percent / 5.0).round

      def self.mastery_for(score_percent)
        return :acquired if reaches?(score_percent, MASTERY_THRESHOLD)
        return :fragile if reaches?(score_percent, PASS_THRESHOLD)

        :struggling
      end
    end
  end
end
