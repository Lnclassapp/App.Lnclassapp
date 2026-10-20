# 🧠 DOMAINE · Entities::Assessment::DailyRotation
# Rôle : choisit la matière de l'exercice du jour (tour d'un cran par jour, saut des matières sans candidat), Ruby pur
# ADR  : 0089 (§4.1 étape 3, §6)
module Entities
  module Assessment
    class DailyRotation
      EPOCH = Date.new(2026, 1, 1)

      # day : date d'Abidjan ; subjects : slugs ordonnés (materials.position, ADR-0090) ; with_candidates : slugs qui ont au moins un
      # candidat ce jour-là (Array ou Set). → le slug du jour, ou nil quand aucune matière n'a de candidat.
      def self.subject_for(day:, subjects:, with_candidates:)
        return nil if subjects.empty?

        start = (day - EPOCH).to_i % subjects.size
        subjects.rotate(start).find { |slug| with_candidates.include?(slug) }
      end
    end
  end
end
