# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Ordering
# Rôle : remettre dans l'ordre : juste seulement si toutes les étapes sont à leur place, sans points partiels
# ADR  : 0091 (§4.2 : trois à six étapes, dans le bon ordre par position ; §4.3 ; §4.4 : indices d'affichage)
module Entities
  module Assessment
    module QuestionKinds
      class Ordering
        STEPS = (3..6)
        INPUT = :display_order
        INVALID = { display_order: [ :wrong_order ] }.freeze

        def self.structure_errors(answers:, **) = STEPS.cover?(answers.size) ? [] : [ :steps_count ]

        # ids : reconstitués par AnswerShuffle, dans l'ordre de l'élève ; chaque étape une fois.
        def self.well_formed?(question, ids) = ids.sort == question.answer_ids.sort

        def self.correct?(question, ids) = ids == question.ids_by_position
      end
    end
  end
end
