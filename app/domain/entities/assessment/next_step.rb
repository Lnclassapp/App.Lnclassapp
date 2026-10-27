# 🧠 DOMAINE · Entities::Assessment::NextStep
# Rôle : le prochain geste de l'enseignant après la lecture de la compréhension d'un exercice assigné (AS-23), en six cas, et la question à reprendre
# ADR  : 0079, 0097 (§4.6) · UDR : 0109 · déterministe : même lecture, même geste ; la vue ne choisit pas
module Entities
  module Assessment
    module NextStep
      # done : élèves présents qui l'ont fait ; pending : présents qui ne l'ont pas fait ; readable : Comprehension.readable?(done) ;
      # dominant : Comprehension.dominant ; decline : élèves en baisse. Le premier cas vrai l'emporte (ADR-0097 §4.6).
      # → nil | :remind | :look_at_each | :revisit_notion | :revisit_questions | :watch_decline | :move_on
      def self.for(done:, pending:, readable:, dominant:, decline:)
        return if done.zero?
        return pending.positive? ? :remind : :look_at_each unless readable
        return :revisit_notion if dominant == :struggling
        return :revisit_questions if dominant == :fragile

        decline.positive? ? :watch_decline : :move_on
      end

      # Décision du porteur (2026-10-26, maquette) : « Reprenez la question 3 en classe ». rates : le taux de réussite de chaque
      # question, dans l'ordre de l'exercice, nil sans tentative. → le numéro (à partir de 1) de la moins réussie, la première à
      # égalité ; nil si aucune question n'a de tentative : le geste ne nomme alors aucune question.
      def self.weakest_question(rates)
        lowest = rates.compact.min
        rates.index(lowest) + 1 unless lowest.nil?
      end
    end
  end
end
