# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Blanks
# Rôle : les cases d'une question (un `___` chacune, de 0 à 5) : réponses rangées par case, nombre de cases, refus de `blank` > 0
# ADR  : XXXX-questions-a-plusieurs-cases-et-indice (§4 : cases numérotées par l'ordre des `___`, au plus 6)
module Entities
  module Assessment
    module QuestionKinds
      module Blanks
        MAX = 6
        MARKER = "___".freeze

        # Les réponses rangées par case, de la case 0 à la plus haute ; une case sans réponse est une liste vide, une question sans
        # réponse a une case. Une réponse sans `blank` est celle de la case 0. → [[Answer]]
        def self.cases(answers)
          count = (answers.map { it.blank.to_i }.max || 0) + 1
          Array.new(count) { |blank| answers.select { it.blank.to_i == blank } }
        end

        def self.markers(content) = content.to_s.scan(MARKER).size

        # Les types à une seule case refusent une réponse rattachée à une autre case.
        def self.single_case_errors(answers) = answers.any? { it.blank.to_i.positive? } ? [ :blank_not_allowed ] : []

        # Plus de six cases, ou autant de `___` que de cases quand il y en a plusieurs. Avec une seule case, chaque type garde sa règle.
        def self.layout_errors(content, cases)
          errors = []
          errors << :too_many_blanks if cases.size > MAX
          errors << :blank_markers_mismatch if cases.size > 1 && markers(content) != cases.size
          errors
        end
      end
    end
  end
end
