# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::FillBlank
# Rôle : texte à trous : juste sans tenir compte des majuscules, des accents ni des espaces en trop ; une faute de frappe est fausse ; jugé case par case
# ADR  : 0091 (§4.2 : une à cinq réponses acceptées, `___` une fois dans l'énoncé ; §4.3 : la normalisation), 0115, 0120-questions-a-plusieurs-cases-et-indice (§4)
module Entities
  module Assessment
    module QuestionKinds
      class FillBlank
        MARKER = "___"
        ACCEPTED = (1..5)
        AUTO_GRADED = true
        INPUT = :response_text
        INVALID = { response_text: [ :blank_text ] }.freeze
        # Apostrophes typographiques du clavier d'un téléphone (’ ‘ ʼ) : la même apostrophe que celle de l'enseignant.
        APOSTROPHES = /[’‘ʼ]/

        # Tirets Unicode (‐ ‑ ‒ – — ― et le moins −) : le trait d'union du clavier.
        DASHES = /[\u2010-\u2015\u2212]/
        LIGATURES = { "œ" => "oe", "æ" => "ae" }.freeze

        # Minuscules, accents décomposés puis retirés, ligatures œ et æ dépliées, apostrophes et tirets unifiés, espaces réduits
        # à un seul et retirés aux bords. Aucune distance d'édition : « Abidjn » n'est pas « Abidjan ».
        def self.normalize(text)
          text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[œæ]/, LIGATURES).gsub(APOSTROPHES, "'")
              .gsub(DASHES, "-").gsub(/[[:space:]]+/, " ").strip
        end

        # Une case : `___` une fois, de 1 à 5 réponses acceptées. Plusieurs cases : autant de `___` que de cases, chacune avec ses
        # propres réponses (de 1 à 5), distinctes entre elles.
        def self.structure_errors(content:, answers:, **)
          cases = Blanks.cases(answers)
          errors = Blanks.layout_errors(content, cases)
          errors << :blank_marker if cases.size == 1 && content.scan(MARKER).size != 1
          cases.each do |accepted|
            errors << (accepted.empty? && cases.size > 1 ? :blank_without_answer : :accepted_answers_count) unless ACCEPTED.cover?(accepted.size)
            errors << :duplicate_accepted if duplicates?(accepted.map(&:content))
          end
          errors.uniq
        end

        # Deux textes égaux une fois normalisés : la même réponse acceptée, saisie deux fois.
        def self.duplicates?(texts)
          normalized = texts.map { normalize(it) }.reject(&:empty?)
          normalized.uniq.size != normalized.size
        end

        # Une case : un texte non vide. Plusieurs cases : un texte par case, vide admis (la case est alors fausse).
        def self.well_formed?(question, response)
          return !normalize(response).empty? if question.blanks == 1 && !response.is_a?(Array)

          response.is_a?(Array) && response.size == question.blanks && response.all?(String)
        end

        # Le verdict de chaque case, dans l'ordre des cases. response : un texte (une case) ou une liste de textes. → [Boolean]
        def self.blank_results(question, response)
          texts = Array(response)
          Blanks.cases(question.answers).each_with_index.map do |accepted, index|
            given = normalize(texts[index])
            !given.empty? && accepted.any? { normalize(it.content) == given }
          end
        end

        def self.correct?(question, response) = blank_results(question, response).all?
      end
    end
  end
end
