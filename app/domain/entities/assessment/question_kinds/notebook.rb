# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Notebook
# Rôle : travail sur le cahier : une consigne sans champ, jamais noté ; le corrigé type en texte est obligatoire
# ADR  : 0115 (§4)
module Entities
  module Assessment
    module QuestionKinds
      class Notebook
        AUTO_GRADED = false
        # Aucune réponse à lire.
        INPUT = :none
        INVALID = {}.freeze

        def self.structure_errors(answers:, explanation:, **)
          errors = []
          errors << :explanation_required if explanation.to_s.strip.empty?
          errors << :answers_not_allowed if answers.any?
          errors
        end

        def self.well_formed?(_question, _response) = true

        def self.correct?(_question, _response) = false
      end
    end
  end
end
