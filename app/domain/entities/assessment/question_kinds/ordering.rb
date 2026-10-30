# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Ordering
# Rôle : remettre dans l'ordre : juste seulement si toutes les étapes sont à leur place, sans points partiels
# ADR  : 0091 (§4.2 : trois à six étapes, dans le bon ordre par position ; §4.3 ; §4.4 : indices d'affichage), 0115, XXXX-questions-a-plusieurs-cases-et-indice (§4 : une seule case)
module Entities
  module Assessment
    module QuestionKinds
      class Ordering
        STEPS = (3..6)
        AUTO_GRADED = true
        INPUT = :display_order
        INVALID = { display_order: [ :wrong_order ] }.freeze

        # Deux étapes de même texte rendraient l'ordre ambigu : l'élève ne saurait laquelle est laquelle.
        def self.structure_errors(answers:, **)
          errors = []
          errors << :steps_count unless STEPS.cover?(answers.size)
          errors << :duplicate_steps if FillBlank.duplicates?(answers.map(&:content))
          errors.concat(Blanks.single_case_errors(answers))
        end

        # Une seule case : le verdict est celui de la question.
        def self.blank_results(question, response) = [ correct?(question, response) ]

        # ids : reconstitués par AnswerShuffle, dans l'ordre de l'élève ; chaque étape une fois.
        def self.well_formed?(question, ids) = ids.sort == question.answer_ids.sort

        def self.correct?(question, ids) = ids == question.ids_by_position
      end
    end
  end
end
