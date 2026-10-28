# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Select
# Rôle : choix dans une liste : 2 à 10 propositions, une seule correcte ; le trou ___ est facultatif, au plus une fois
# ADR  : 0115 (§4 : corrigé automatiquement, la réponse est l'identifiant de la proposition choisie)
module Entities
  module Assessment
    module QuestionKinds
      class Select
        AUTO_GRADED = true
        OPTIONS = (2..10)
        INPUT = :answer_ids
        INVALID = { answer_ids: [ :wrong_selection ] }.freeze

        # Propositions distinctes (une liste à deux entrées égales ne se corrige pas) et non vides (une ligne vide, invisible dans la liste).
        def self.structure_errors(content:, answers:, **)
          errors = []
          errors << :options_count unless OPTIONS.cover?(answers.size)
          errors << :wrong_correct_count unless answers.count(&:correct) == 1
          errors << :blank_marker if content.scan(FillBlank::MARKER).size > 1
          errors << :blank_option if answers.any? { FillBlank.normalize(it.content).empty? }
          errors << :duplicate_options if FillBlank.duplicates?(answers.map(&:content))
          errors
        end

        # Une seule proposition, de cette question.
        def self.well_formed?(question, ids) = ids.size == 1 && question.answer_ids.include?(ids.first)

        def self.correct?(question, ids) = ids == question.correct_answer_ids
      end
    end
  end
end
