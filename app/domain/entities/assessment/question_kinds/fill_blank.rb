# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::FillBlank
# Rôle : texte à trous : juste sans tenir compte des majuscules, des accents ni des espaces en trop ; une faute de frappe est fausse
# ADR  : 0091 (§4.2 : une à cinq réponses acceptées, `___` une fois dans l'énoncé ; §4.3 : la normalisation)
module Entities
  module Assessment
    module QuestionKinds
      class FillBlank
        MARKER = "___"
        ACCEPTED = (1..5)
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

        def self.structure_errors(content:, answers:, **)
          errors = []
          errors << :blank_marker unless content.scan(MARKER).size == 1
          errors << :accepted_answers_count unless ACCEPTED.cover?(answers.size)
          errors << :duplicate_accepted if duplicates?(answers.map(&:content))
          errors
        end

        # Deux textes égaux une fois normalisés : la même réponse acceptée, saisie deux fois.
        def self.duplicates?(texts)
          normalized = texts.map { normalize(it) }.reject(&:empty?)
          normalized.uniq.size != normalized.size
        end

        def self.well_formed?(_question, text) = !normalize(text).empty?

        def self.correct?(question, text)
          given = normalize(text)
          question.answers.any? { normalize(it.content) == given }
        end
      end
    end
  end
end
