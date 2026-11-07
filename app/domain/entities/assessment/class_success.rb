# 🧠 DOMAINE · Entities::Assessment::ClassSuccess
# Rôle : la réussite d'une classe sur un exercice : élèves présents, élèves ayant réussi (meilleure copie terminée de chacun)
# ADR  : lecture-de-la-classe-par-la-direction, 0106 · UDR : suivi-de-la-classe-sur-une-lecon §3.2
module Entities
  module Assessment
    ClassSuccess = Data.define(:exercise_id, :present_count, :done_count, :passed_count) do
      # exercise_id : le public_id de l'exercice (ancre de la ligne). scores_by_student : { élève => [score_percent de ses copies terminées] } ; un élève compte une fois, sur sa meilleure copie.
      # Réussi = la note affichée atteint celle du seuil de réussite (Grading.reaches?, ADR-0106).
      def self.build(exercise_id:, present_count:, scores_by_student:)
        bests = scores_by_student.values.reject(&:empty?).map(&:max)
        new(exercise_id:, present_count:, done_count: bests.size,
            passed_count: bests.count { Grading.reaches?(it, Grading::PASS_THRESHOLD) })
      end

      def done? = done_count.positive?
    end
  end
end
