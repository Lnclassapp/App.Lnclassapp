# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Select
# Rôle : choix dans une liste : 2 à 10 propositions, une seule correcte ; le trou ___ est facultatif avec une case ; jugé case par case
# ADR  : 0115 (§4 : corrigé automatiquement, la réponse est l'identifiant de la proposition choisie), 0120-questions-a-plusieurs-cases-et-indice (§4)
module Entities
  module Assessment
    module QuestionKinds
      class Select
        AUTO_GRADED = true
        OPTIONS = (2..10)
        INPUT = :answer_ids
        INVALID = { answer_ids: [ :wrong_selection ] }.freeze

        # Propositions distinctes (une liste à deux entrées égales ne se corrige pas) et non vides (une ligne vide, invisible dans la liste).
        # Chaque case a ses propositions (de 2 à 10, une seule correcte, distinctes). Une case : `___` au plus une fois ; plusieurs :
        # autant de `___` que de cases.
        def self.structure_errors(content:, answers:, **)
          cases = Blanks.cases(answers)
          errors = Blanks.layout_errors(content, cases)
          errors << :blank_marker if cases.size == 1 && content.scan(FillBlank::MARKER).size > 1
          cases.each do |options|
            errors << (options.empty? && cases.size > 1 ? :blank_without_answer : :options_count) unless OPTIONS.cover?(options.size)
            errors << :wrong_correct_count unless options.count(&:correct) == 1 || (options.empty? && cases.size > 1)
            errors << :blank_option if options.any? { FillBlank.normalize(it.content).empty? }
            errors << :duplicate_options if FillBlank.duplicates?(options.map(&:content))
          end
          errors.uniq
        end

        # Une case : une seule proposition, de cette question. Plusieurs cases : une proposition par case (nil : case laissée vide),
        # chacune de sa case.
        def self.well_formed?(question, ids)
          return ids.size == 1 && question.answer_ids.include?(ids.first) if question.blanks == 1

          cases = Blanks.cases(question.answers)
          ids.size == cases.size && ids.each_with_index.all? { |id, index| id.nil? || cases[index].any? { it.id == id } }
        end

        # Le verdict de chaque case : la proposition choisie est la correcte de sa case. ids : un identifiant par case. → [Boolean]
        def self.blank_results(question, ids)
          chosen = Array(ids)
          Blanks.cases(question.answers).each_with_index.map { |options, index| !chosen[index].nil? && options.find(&:correct)&.id == chosen[index] }
        end

        # Le texte de la proposition choisie dans chaque case (vide si la case est laissée vide), pour question_attempts.blank_responses.
        def self.blank_texts(question, ids)
          contents = question.answers.to_h { [ it.id, it.content ] }
          Array(ids).map { contents.fetch(it, "") }
        end

        def self.correct?(question, ids)
          return ids == question.correct_answer_ids if question.blanks == 1

          blank_results(question, ids).all?
        end
      end
    end
  end
end
