# 🧠 DOMAINE · Entities::Catalog::ContentNode
# Rôle : validateurs des cours, fiches et exercices importés, partagés par les trois imports de contenu
# ADR  : 0035, 0039, 0091 (§4.5 : tolerance et match), 0105, 0115, 0116
module Entities
  module Catalog
    module ContentNode
      # Clés JSON (chaînes) de l'ancienne application ; la clé status est ignorée : tout naît draft.
      def self.validate_exercise(hash, path:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        errors = text(hash, "title", Assessment::Exercise::TITLE_MAX, path)
        unless Assessment::Exercise::TYPES.include?(hash["exercise_type"])
          errors << error("#{path}.exercise_type", "invalid_value", value: hash["exercise_type"])
        end
        errors += statement_blocks_errors(hash["statement_blocks"], path)
        questions = Array(hash["questions"])
        return errors << error("#{path}.questions", "blank") if questions.empty?

        errors + questions.each_with_index.flat_map { |question, index| question_errors(question, "#{path}.questions[#{index}]") }
      end

      # Format 3 (ADR-0116 §4.1) : la leçon sans ses enfants, qu'ImportCourseTree valide un à un.
      def self.validate_lesson(hash, path:, lookup:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        text(hash, "name", Course::NAME_MAX, path) + text(hash, "subtitle", Course::SUBTITLE_MAX, path, required: false) +
          taxonomy(hash, path, lookup)
      end

      # Une notion v3 : son nom et sa fiche au gabarit (NotionSheet). La figure citée et l'exercice sont vérifiés à part.
      def self.validate_notion(hash, path:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        text(hash, "name", Essential::NAME_MAX, path) +
          NotionSheet.errors_for(hash).map { |sub_path, code| error("#{path}.#{sub_path}", code) }
      end

      # Les figures de la leçon : chacune valide (Figure), clés uniques. → Array<ImportError>
      def self.validate_figures(figures, path)
        return [] unless figures.is_a?(Array)

        seen = Set.new
        figures.each_with_index.flat_map do |figure, index|
          figure_path = "#{path}.figures[#{index}]"
          found = Figure.errors_for(figure).map { |sub_path, code, params| error(sub_path == "$" ? figure_path : "#{figure_path}.#{sub_path}", code, **params) }
          duplicate = figure.is_a?(Hash) && figure["key"].is_a?(String) && !seen.add?(figure["key"])
          duplicate ? found << error("#{figure_path}.key", "figure_invalid", param: "key") : found
        end
      end

      # Une figure citée par une notion ou un exercice doit être dans la leçon. → Array<ImportError>
      def self.validate_figure_citation(key, keys, path)
        return [] if key.nil? || key.to_s.empty? || keys.include?(key)

        [ error(path, "figure_missing", key: key.to_s) ]
      end

      # Un exercice v3 : les règles de l'exercice, 5 à 30 questions (le plafond est celui du schéma) et la correction rédigée de
      # chaque question, de 20 à 2 000 caractères.
      def self.validate_exercise_v3(hash, path:)
        errors = validate_exercise(hash, path:)
        return errors unless hash.is_a?(Hash)

        questions = Array(hash["questions"])
        if questions.size < QUESTIONS_MIN
          # Aucune question : « trop peu », pas « vide » (la raison de validate_exercise est remplacée).
          errors = errors.reject { it.path == "#{path}.questions" && it.code == "blank" }
          errors << error("#{path}.questions", "too_few_questions", title: hash["title"].to_s.squish, count: questions.size,
                                                                     min: QUESTIONS_MIN)
        elsif questions.size > QUESTIONS_MAX
          errors << error("#{path}.questions", "invalid_count")
        end
        errors + questions.each_with_index.flat_map { |question, index| explanation_errors(question, "#{path}.questions[#{index}]") }
      end

      def self.explanation_errors(question, path)
        return [] unless question.is_a?(Hash)

        explanation = question["explanation"].to_s.squish
        key = "#{path}.explanation"
        return [ error(key, "blank") ] if explanation.empty?
        return [ error(key, "too_short", min: EXPLANATION_RANGE.min) ] if explanation.length < EXPLANATION_RANGE.min
        return [ error(key, "too_long", max: EXPLANATION_RANGE.max) ] if explanation.length > EXPLANATION_RANGE.max

        []
      end

      # ADR-0115, menace I9 : le sujet en blocs est lu comme un fichier hostile avant d'être écrit (StatementBlocks : dix blocs au
      # plus, de types paragraph, box et table, texte sans HTML ni lien). Une liste vide vaut l'absence de blocs.
      def self.statement_blocks_errors(blocks, path)
        key = "#{path}.statement_blocks"
        StatementBlocks.errors(blocks).map do |found|
          if found.position.nil?
            error(key, "schema")
          elsif found.reason == :unknown_type
            error("#{key}[#{found.position - 1}].type", "invalid_value", value: found.detail)
          else
            error("#{key}[#{found.position - 1}]", "invalid_value", value: [ found.reason, found.detail ].compact.join(" : "))
          end
        end
      end

      # L'ancienne application nomme is_correct ce que le schéma nomme correct ; match est le côté droit d'une paire.
      def self.question_errors(hash, path)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        raw_answers = Array(hash["answers"])
        return [ error("#{path}.answers", "schema") ] unless raw_answers.all?(Hash)

        answers = raw_answers.each_with_index.map do |answer, index|
          Assessment::Answer.new(id: index, position: index, content: answer["content"],
                                 correct: answer.fetch("correct") { answer["is_correct"] } == true,
                                 match_content: answer["match"].to_s.strip.presence)
        end
        errors = text(hash, "content", nil, path)
        errors += raw_answers.each_with_index.flat_map { |answer, index| text(answer, "content", nil, "#{path}.answers[#{index}]") }
        typed = typing_errors(hash, path)
        return errors + typed if typed.any?

        errors + misplaced_keys(hash, raw_answers, path) + structure_errors(hash, answers, path) + image_errors(hash["image"], path)
      end

      # ADR-0115 : le schéma a déjà vérifié la forme de points, unit, starter et criteria ; l'adaptateur la revérifie pour ne jamais
      # lire un type inattendu si on l'appelle sans lui (un nombre fini, des textes, une liste de textes).
      def self.typing_errors(hash, path)
        errors = []
        points = hash["points"]
        errors << error("#{path}.points", "schema") unless points.nil? || (points.is_a?(::Numeric) && points.finite?)
        %w[unit starter].each { |key| errors << error("#{path}.#{key}", "schema") unless hash[key].nil? || hash[key].is_a?(String) }
        criteria = hash["criteria"]
        errors << error("#{path}.criteria", "schema") unless criteria.nil? || (criteria.is_a?(Array) && criteria.all?(String))
        errors
      end

      # ADR-0105 §4.6 : le schéma a vérifié la forme et la longueur ; une description faite d'espaces n'en est pas une.
      def self.image_errors(image, path)
        return [] unless image.is_a?(Hash) && image["description"].is_a?(String)

        text(image, "description", nil, "#{path}.image")
      end

      # ADR-0091 §4.5 : tolerance n'a de sens que pour un nombre, match que pour relier ; ailleurs, une clé ignorée
      # tromperait l'équipe : elle est refusée à sa place.
      def self.misplaced_keys(hash, raw_answers, path)
        errors = []
        if hash.key?("tolerance") && !hash["tolerance"].nil? && hash["question_type"] != "numeric"
          errors << error("#{path}.tolerance", "question_structure", rule: :tolerance_not_allowed)
        end
        return errors if hash["question_type"] == "matching"

        errors + raw_answers.each_with_index.filter_map do |answer, index|
          next if answer["match"].nil?

          error("#{path}.answers[#{index}].match", "question_structure", rule: :match_not_allowed)
        end
      end

      # Une règle se rapporte à l'énoncé, à la marge, ou aux éléments de la question.
      RULE_KEYS = { blank_marker: "content", negative_tolerance: "tolerance", tolerance_out_of_range: "tolerance",
                    points_out_of_range: "points", unit_not_allowed: "unit", unit_too_long: "unit", unit_invalid: "unit",
                    starter_not_allowed: "starter", starter_too_long: "starter", criteria_not_allowed: "criteria",
                    criteria_too_many: "criteria", criteria_too_long: "criteria", criteria_blank: "criteria",
                    explanation_required: "explanation" }.freeze
      QUESTIONS_MIN = 5
      QUESTIONS_MAX = 30
      EXPLANATION_RANGE = (20..2_000)
      STATEMENT_BLOCK_TYPES = StatementBlocks::TYPES
      STATEMENT_BLOCKS_MAX = StatementBlocks::MAX

      def self.structure_errors(hash, answers, path)
        question_type = hash["question_type"]
        tolerance = hash["tolerance"]
        points = hash["points"]
        rules = Assessment::Question.structure_errors_for(
          question_type:, answers:, content: hash["content"], numeric_tolerance: tolerance.is_a?(::Numeric) ? BigDecimal(tolerance.to_s) : nil,
          explanation: hash["explanation"], points: points.nil? ? BigDecimal("1") : BigDecimal(points.to_s), unit: hash["unit"],
          starter: hash["starter"], criteria: Array(hash["criteria"])
        )
        return [ error("#{path}.question_type", "invalid_value", value: question_type) ] if rules == [ :unknown_question_type ]

        rules.map { |rule| error("#{path}.#{RULE_KEYS.fetch(rule, 'answers')}", "question_structure", rule:) }
      end

      def self.taxonomy(hash, path, lookup)
        level = lookup.resolve_level(hash["level_name"])
        material = lookup.resolve_material(hash["material_name"])
        errors = []
        errors << error("#{path}.level_name", "unknown_level", value: hash["level_name"]) if level.nil?
        errors << error("#{path}.material_name", "unknown_material", value: hash["material_name"]) if material.nil?
        errors + series_errors(hash, path, lookup, level)
      end

      # Une série est facultative ; donnée, elle doit exister et être liée au niveau.
      def self.series_errors(hash, path, lookup, level)
        name = hash["series_name"]
        return [] if name.to_s.strip.empty?

        series = lookup.resolve_series(name)
        return [ error("#{path}.series_name", "unknown_series", value: name) ] if series.nil?
        return [ error("#{path}.series_name", "series_not_allowed", value: name) ] if level && !lookup.pair?(level.id, series.id)

        []
      end

      def self.text(hash, key, max, path, required: true)
        value = hash[key].to_s.squish
        return [] if value.empty? && !required
        return [ error("#{path}.#{key}", "blank") ] if value.empty?
        return [ error("#{path}.#{key}", "too_long", max:) ] if max && value.length > max

        []
      end

      def self.children(hash, key, path)
        Array(hash[key]).each_with_index.flat_map { |child, index| yield(child, "#{path}.#{key}[#{index}]") }
      end

      def self.error(path, code, **params) = ImportError.new(path:, code:, params:)

      private_class_method :question_errors, :typing_errors, :statement_blocks_errors, :misplaced_keys, :structure_errors, :image_errors, :taxonomy,
                           :series_errors, :text, :children, :error, :explanation_errors
    end
  end
end
