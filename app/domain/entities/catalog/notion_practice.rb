# 🧠 DOMAINE · Entities::Catalog::NotionPractice
# Rôle : l'exercice d'entraînement facultatif d'une notion (fiche, clé practice) : sa forme, son empreinte et sa copie sans correction
# ADR  : 0119-entrainement-de-notion-corrige-sans-trace (§4, §6), 0120-questions-a-plusieurs-cases-et-indice · UDR : 0147-je-m-entraine-dans-la-fiche
require "digest"
require "json"

module Entities
  module Catalog
    # questions : [Entities::Assessment::Question], id = position (0..n-1), jamais en base ; digest : l'empreinte de version.
    NotionPractice = Data.define(:statement, :questions, :digest) do
      def self.from_raw(raw)
        return nil unless raw.is_a?(Hash)

        new(statement: raw["statement"].to_s.strip, digest: digest_of(raw),
            questions: Array(raw["questions"]).each_with_index.map { |question, index| question_from(question, index) })
      end

      # Les 16 premiers caractères hexadécimaux du SHA-256 du JSON canonique (clés triées à tous les niveaux : jsonb ne garde pas
      # l'ordre des clés d'un fichier). → String
      def self.digest_of(raw) = Digest::SHA256.hexdigest(JSON.generate(canonical(raw)))[0, 16]

      # → Array<[chemin, raison, params]> ; vide si l'entraînement est conforme. Ne lève jamais, quelle que soit la forme reçue.
      # Le chemin "$" est l'entraînement lui-même. Chaque question suit les règles de structure des exercices notés (Question).
      def self.errors_for(raw)
        return [ violation("$", "schema") ] unless raw.is_a?(Hash)

        questions = raw["questions"]
        errors = statement_errors(raw["statement"])
        errors << violation("questions", "invalid_count") unless questions.is_a?(Array) && NotionPractice::QUESTIONS.cover?(questions.size)
        questions = [] unless questions.is_a?(Array)
        errors + questions.each_with_index.flat_map { |question, index| question_errors(question, "questions[#{index}]") }
      end

      # Copie montrable avant « Vérifier » : ni correct, ni corrigé, ni valeur attendue. Les types dont les réponses sont la
      # solution (chiffré, trous, rédigé, cahier) perdent leurs réponses ; les propositions d'une liste ou d'un QCM gardent leur texte.
      def without_correction = with(questions: questions.map { |question| self.class.shown(question) })

      def self.shown(question)
        hidden = question.without_correction.with(explanation: nil)
        NotionPractice::SHOWS_ANSWERS.include?(question.kind_name) ? hidden : hidden.with(answers: [])
      end

      def self.canonical(value)
        case value
        when Hash then value.sort_by { |key, _| key.to_s }.to_h { |key, item| [ key.to_s, canonical(item) ] }
        when Array then value.map { |item| canonical(item) }
        else value
        end
      end

      # La question de l'exercice, comme l'écrit ContentTreeWriterPort::QuestionNode : hors choix et liste, chaque élément est juste.
      def self.question_from(raw, index)
        choice = %w[choice select].include?(Assessment::Question.kind_name_for(raw["question_type"]))
        answers = Array(raw["answers"]).each_with_index.map do |answer, rank|
          Assessment::Answer.new(id: rank, position: rank + 1, content: answer["content"].to_s.strip, correct: !choice || correct_in?(answer),
                                 match_content: answer["match"].to_s.strip.presence, blank: answer["blank"] || 0)
        end
        Assessment::Question.new(id: index, position: index + 1, content: raw["content"].to_s.strip, explanation: raw["explanation"].to_s.strip.presence,
                                 question_type: raw["question_type"], answers:, numeric_tolerance: raw["tolerance"]&.then { BigDecimal(it.to_s) },
                                 unit: raw["unit"].to_s.strip.presence, starter: raw["starter"].to_s.strip.presence, hint: raw["hint"].to_s.strip.presence)
      end

      # L'ancienne application nomme is_correct ce que le schéma nomme correct : un seul lecteur pour la copie et la validation.
      def self.correct_in?(answer) = answer.fetch("correct") { answer["is_correct"] } == true

      def self.statement_errors(statement)
        return [] if statement.nil?
        return [ violation("statement", "schema") ] unless statement.is_a?(String)

        statement.length > NotionPractice::STATEMENT_MAX ? [ violation("statement", "too_long") ] : []
      end

      def self.question_errors(raw, path)
        return [ violation(path, "schema") ] unless raw.is_a?(Hash)

        forbidden = NotionPractice::FORBIDDEN_KEYS.select { raw.key?(it) }.map { violation("#{path}.#{it}", "invalid_value") }
        shape = shape_errors(raw, path)
        text = text_errors(raw, path)
        return forbidden + text + shape if shape.any? || Assessment::Question.kind_for(raw["question_type"]).nil?

        forbidden + text + structure_errors(raw, path)
      end

      # Types et bornes : tant qu'ils ne tiennent pas, la structure n'est pas jugée (elle lirait un type inattendu).
      def self.shape_errors(raw, path)
        errors = []
        errors << violation("#{path}.question_type", "invalid_value") if Assessment::Question.kind_for(raw["question_type"]).nil?
        errors << violation("#{path}.hint", raw["hint"].is_a?(String) ? "too_long" : "schema") unless hint_ok?(raw["hint"])
        errors << violation("#{path}.tolerance", "schema") unless raw["tolerance"].nil? || (raw["tolerance"].is_a?(::Numeric) && raw["tolerance"].finite?)
        %w[unit starter].each { |key| errors << violation("#{path}.#{key}", "schema") unless raw[key].nil? || raw[key].is_a?(String) }
        errors + answers_shape_errors(raw["answers"], path)
      end

      def self.hint_ok?(hint) = hint.nil? || (hint.is_a?(String) && hint.length <= NotionPractice::HINT_MAX)

      def self.answers_shape_errors(answers, path)
        return [ violation("#{path}.answers", "schema") ] unless answers.is_a?(Array) && answers.all?(Hash)

        answers.each_with_index.filter_map do |answer, index|
          blank = answer["blank"]
          next if blank.nil? || (blank.is_a?(Integer) && NotionPractice::BLANKS.cover?(blank))

          violation("#{path}.answers[#{index}].blank", blank.is_a?(Integer) ? "invalid_value" : "schema")
        end
      end

      # Énoncé non vide, corrigé de 20 à 2 000 caractères, propositions non vides.
      def self.text_errors(raw, path)
        errors = []
        errors << violation("#{path}.content", "blank") if raw["content"].to_s.squish.empty?
        errors.concat(explanation_errors(raw["explanation"].to_s.squish, "#{path}.explanation"))
        Array(raw["answers"]).each_with_index do |answer, index|
          errors << violation("#{path}.answers[#{index}].content", "blank") if answer.is_a?(Hash) && answer["content"].to_s.squish.empty?
        end
        errors
      end

      def self.explanation_errors(explanation, path)
        return [ violation(path, "blank") ] if explanation.empty?
        return [ violation(path, "too_short", min: NotionPractice::EXPLANATION.min) ] if explanation.length < NotionPractice::EXPLANATION.min
        return [ violation(path, "too_long", max: NotionPractice::EXPLANATION.max) ] if explanation.length > NotionPractice::EXPLANATION.max

        []
      end

      def self.structure_errors(raw, path)
        type = raw["question_type"]
        tolerance = raw["tolerance"]
        answers = raw["answers"].each_with_index.map do |answer, index|
          Assessment::Answer.new(id: index, position: index, content: answer["content"], correct: correct_in?(answer),
                                 match_content: answer["match"].to_s.strip.presence, blank: answer["blank"] || 0)
        end
        rules = Assessment::Question.structure_errors_for(question_type: type, answers:, content: raw["content"],
                                                          numeric_tolerance: tolerance&.then { BigDecimal(it.to_s) },
                                                          explanation: raw["explanation"], unit: raw["unit"], starter: raw["starter"])
        misplaced = []
        misplaced << :tolerance_not_allowed if !tolerance.nil? && type != "numeric"
        misplaced << :match_not_allowed if type != "matching" && raw["answers"].any? { !it["match"].nil? }
        (rules + misplaced).map { |rule| violation("#{path}.#{NotionPractice::RULE_PATHS.fetch(rule, 'answers')}", "question_structure", rule:) }
      end

      def self.violation(path, code, **params) = [ path, code, params ]

      private_class_method :canonical, :question_from, :correct_in?, :statement_errors, :question_errors, :shape_errors, :hint_ok?, :answers_shape_errors,
                           :text_errors, :explanation_errors, :structure_errors, :violation
    end

    NotionPractice::QUESTIONS = (1..6)
    NotionPractice::FORBIDDEN_KEYS = %w[points image criteria].freeze
    NotionPractice::STATEMENT_MAX = 1_200
    NotionPractice::HINT_MAX = 500
    NotionPractice::BLANKS = (0..5)
    NotionPractice::EXPLANATION = (20..2_000)
    NotionPractice::RULE_PATHS = ContentNode::RULE_KEYS.merge(tolerance_not_allowed: "tolerance", match_not_allowed: "answers").freeze
    NotionPractice::SHOWS_ANSWERS = %w[choice select ordering matching].freeze
  end
end
