# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Notebook
# Rôle : travail sur le cahier : une consigne sans champ, jamais noté ; le corrigé type en texte est obligatoire
# ADR  : 0115 (§4), XXXX-questions-a-plusieurs-cases-et-indice (§4 : une seule case)
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
          errors.concat(Blanks.single_case_errors(answers))
        end

        def self.well_formed?(_question, _response) = true

        def self.correct?(_question, _response) = false

        # Une seule case, jamais notée : le verdict est faux.
        def self.blank_results(question, response) = [ correct?(question, response) ]
      end
    end
  end
end
