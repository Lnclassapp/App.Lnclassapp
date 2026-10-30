# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Choice
# Rôle : Vrai / Faux, choix unique, 2 ou 3 propositions correctes : cocher le bon ensemble de propositions
# ADR  : 0039, 0054, 0091 (§4.3 : comportement d'avant, déplacé de Question), 0115, XXXX-questions-a-plusieurs-cases-et-indice (§4 : une seule case)
module Entities
  module Assessment
    module QuestionKinds
      class Choice
        EXPECTED = { true_false: 1, single_choice: 1, multiple_correct_2: 2, multiple_correct_3: 3 }.freeze
        # Ce que la page poste : attempt[answer_ids][].
        AUTO_GRADED = true
        INPUT = :answer_ids
        INVALID = { answer_ids: [ :wrong_selection ] }.freeze

        # Hors Vrai/Faux, au moins une proposition incorrecte s'ajoute aux correctes : N correctes → N + 1 propositions.
        def self.structure_errors(question_type:, answers:, **)
          expected = EXPECTED.fetch(question_type.to_sym)
          errors = []
          errors << :true_false_needs_two_answers if question_type == "true_false" && answers.size != 2
          errors << :too_few_answers if question_type != "true_false" && answers.size <= expected
          errors << :wrong_correct_count if answers.count(&:correct) != expected
          errors.concat(Blanks.single_case_errors(answers))
        end

        # Une seule case : le verdict est celui de la question.
        def self.blank_results(question, response) = [ correct?(question, response) ]

        # Nombre attendu de propositions distinctes, toutes de cette question.
        def self.well_formed?(question, ids)
          ids.uniq.size == ids.size && ids.size == question.expected_count && (ids - question.answer_ids).empty?
        end

        # Égalité exacte des ensembles d'identifiants.
        def self.correct?(question, ids) = ids.sort == question.correct_answer_ids.sort
      end
    end
  end
end
