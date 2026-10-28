# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Matching
# Rôle : relier : juste seulement si chaque élément de gauche est relié au sien, sans points partiels
# ADR  : 0091 (§4.2 : trois à cinq paires, côtés droits distincts ; §4.3 ; §4.4 : indices d'affichage), 0115
module Entities
  module Assessment
    module QuestionKinds
      class Matching
        PAIRS = (3..5)
        AUTO_GRADED = true
        INPUT = :display_order
        INVALID = { display_order: [ :incomplete_pairs ] }.freeze

        def self.structure_errors(answers:, **)
          rights = answers.map { it.match_content.to_s.strip }
          errors = []
          errors << :pairs_count unless PAIRS.cover?(answers.size)
          errors << :missing_match if rights.any?(&:empty?)
          errors << :duplicate_match if FillBlank.duplicates?(rights)
          errors << :duplicate_left if FillBlank.duplicates?(answers.map(&:content))
          errors
        end

        # ids : pour chaque élément de gauche, dans l'ordre des positions, l'id de l'élément de droite choisi ; chacun une fois.
        def self.well_formed?(question, ids) = ids.sort == question.answer_ids.sort

        # La droite d'une paire est sur la même ligne answers que sa gauche : juste si chaque gauche a choisi sa propre ligne.
        def self.correct?(question, ids) = ids == question.ids_by_position
      end
    end
  end
end
