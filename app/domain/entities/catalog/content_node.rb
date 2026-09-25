# 🧠 DOMAINE · Entities::Catalog::ContentNode
# Rôle : validateurs des cours, fiches et exercices importés, partagés par les trois imports de contenu
# ADR  : 0035, 0039
module Entities
  module Catalog
    module ContentNode
      # Clés JSON (chaînes) de l'ancienne application ; la clé status est ignorée : tout naît draft.
      def self.validate_course(hash, path:, lookup:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        text(hash, "name", Course::NAME_MAX, path) +
          text(hash, "subtitle", Course::SUBTITLE_MAX, path, required: false) +
          taxonomy(hash, path, lookup) +
          children(hash, "essentials", path) { |essential, child_path| validate_essential(essential, path: child_path) }
      end

      def self.validate_essential(hash, path:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        text(hash, "name", Essential::NAME_MAX, path) +
          text(hash, "subtitle", Essential::SUBTITLE_MAX, path, required: false) +
          children(hash, "exercises", path) { |exercise, child_path| validate_exercise(exercise, path: child_path) }
      end

      def self.validate_exercise(hash, path:)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        errors = text(hash, "title", Assessment::Exercise::TITLE_MAX, path)
        unless Assessment::Exercise::TYPES.include?(hash["exercise_type"])
          errors << error("#{path}.exercise_type", "invalid_value", value: hash["exercise_type"])
        end
        questions = Array(hash["questions"])
        return errors << error("#{path}.questions", "blank") if questions.empty?

        errors + questions.each_with_index.flat_map { |question, index| question_errors(question, "#{path}.questions[#{index}]") }
      end

      # L'ancienne application nomme is_correct ce que le schéma nomme correct.
      def self.question_errors(hash, path)
        return [ error(path, "schema") ] unless hash.is_a?(Hash)

        raw_answers = Array(hash["answers"])
        return [ error("#{path}.answers", "schema") ] unless raw_answers.all?(Hash)

        answers = raw_answers.each_with_index.map do |answer, index|
          Assessment::Answer.new(id: index, position: index, content: answer["content"],
                                 correct: answer.fetch("correct") { answer["is_correct"] } == true)
        end
        errors = text(hash, "content", nil, path)
        errors += raw_answers.each_with_index.flat_map { |answer, index| text(answer, "content", nil, "#{path}.answers[#{index}]") }
        errors + structure_errors(hash["question_type"], answers, path)
      end

      def self.structure_errors(question_type, answers, path)
        rules = Assessment::Question.structure_errors_for(question_type:, answers:)
        return [ error("#{path}.question_type", "invalid_value", value: question_type) ] if rules == [ :unknown_question_type ]

        rules.map { |rule| error("#{path}.answers", "question_structure", rule:) }
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

      private_class_method :question_errors, :structure_errors, :taxonomy, :series_errors, :text, :children, :error
    end
  end
end
