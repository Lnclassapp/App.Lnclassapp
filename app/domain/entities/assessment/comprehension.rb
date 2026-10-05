# 🧠 DOMAINE · Entities::Assessment::Comprehension
# Rôle : lecture de la compréhension d'un exercice assigné : catégorie, signe de progrès, dominante, seuil de lecture
# ADR  : 0033, 0079
module Entities
  module Assessment
    module Comprehension
      PROGRESS_MARGIN = 10
      MIN_DONE_FOR_READING = 5
      # Du plus fragile au plus solide : l'ordre tranche les égalités de la dominante.
      CATEGORIES = %i[struggling fragile acquired].freeze
      # Ordre des élèves d'une catégorie (§4.7) : qui a le plus besoin de l'enseignant d'abord ; nil = un seul essai.
      TREND_ORDER = [ :decline, :stagnant, nil, :stable, :progress ].freeze

      def self.category_for(best) = Grading.mastery_for(best)

      # scores : score_percent des sessions faites, dans l'ordre de completed_at. → nil | :decline | :progress | :stable | :stagnant
      def self.trend_for(scores)
        return if scores.size < 2

        best = scores.max
        return :decline if best - scores.last >= PROGRESS_MARGIN
        return :progress if best - scores.first >= PROGRESS_MARGIN

        best >= Grading::MASTERY_THRESHOLD ? :stable : :stagnant
      end

      # counts : { struggling: n, fragile: n, acquired: n } → la catégorie la plus nombreuse, la plus fragile à égalité ; nil sans élève.
      def self.dominant(counts)
        return if counts.values.sum.zero?

        CATEGORIES.max_by { |category| [ counts.fetch(category, 0), -CATEGORIES.index(category) ] }
      end

      def self.readable?(done) = done >= MIN_DONE_FOR_READING

      def self.to_revisit?(rate) = !rate.nil? && rate < Grading::PASS_THRESHOLD
    end
  end
end
