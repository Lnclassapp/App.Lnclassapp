# 🧠 DOMAINE · Entities::Assessment::Grading
# Rôle : seuils pédagogiques nommés, score, note sur 20, maîtrise et palier de badge, tous lus sur la note affichée
# ADR  : 0033, 0043, 0106, 0115, 0120-questions-a-plusieurs-cases-et-indice (§4, §6 : score en fractions de points)
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

      # UDR enseignant §3.2 : le badge qui range un élève dans une classe, une seule règle. `scores` : les notes retenues (sur 100)
      # de ses exercices assignés faits ; `all_perfect` : chacun est un sans-faute. Diamant : au moins un exercice fait et tous
      # sans faute ; sinon Or, Argent, Bronze selon la moyenne, lue sur la note sur 20 ; nil (« Pas encore ») sans exercice
      # fait ou sous la moyenne de Bronze. Jamais un exercice par élève en requête : l'appelant lit tout en une fois.
      def self.class_badge_for(scores:, all_perfect:)
        return nil if scores.empty?
        return :diamond if all_perfect

        average = scores.sum.fdiv(scores.size)
        GRADED_LEVELS.find { |level| reaches?(average, BADGE_THRESHOLDS[level]) }
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

      # Part des points d'une question que la tentative rapporte, de 0 à 1 (ADR cases §4, §6) : une case, 1 si juste et 0 sinon ;
      # plusieurs, cases justes / cases. Sans tentative, 0. Une question sans case jugée garde `correct` : les tentatives d'avant les cases.
      def self.share(question, attempt)
        return Rational(0) if attempt.nil?

        share_of(blanks: question.blanks, correct: attempt.correct, blank_results: attempt.blank_results)
      end

      # La même règle, pour qui n'a pas la question sous la main (le résultat) : blanks, le nombre de cases de la question. Une
      # question à plusieurs cases sans verdict par case (copie laissée vide) rapporte 0.
      def self.share_of(blanks:, correct:, blank_results:)
        return Rational(correct == true ? 1 : 0) if blanks == 1

        Rational(blank_results.count(true), blanks)
      end

      # ADR-0115, ADR cases §6 : les points rapportés sur ceux des questions corrigées automatiquement, en fractions de points, arrondi
      # vers le bas une seule fois, à la fin. graded : [[points (BigDecimal), part juste (Rational de 0 à 1, ou booléen pour une case)]]
      # des seules questions corrigées automatiquement. Avec toutes les questions à 1 point et une case, c'est score_percent. Sans
      # question corrigée automatiquement, 0.
      def self.points_percent(graded)
        total = graded.sum(Rational(0)) { |points, _| points.to_r }
        return 0 if total.zero?

        (graded.sum(Rational(0)) { |points, share| points.to_r * as_share(share) } * 100 / total).floor
      end

      def self.as_share(share)
        return Rational(share ? 1 : 0) if share == true || share == false || share.nil?

        share.to_r
      end
      private_class_method :as_share

      def self.grade_on_20(score_percent) = (score_percent / 5.0).round

      def self.mastery_for(score_percent)
        return :acquired if reaches?(score_percent, MASTERY_THRESHOLD)
        return :fragile if reaches?(score_percent, PASS_THRESHOLD)

        :struggling
      end
    end
  end
end
