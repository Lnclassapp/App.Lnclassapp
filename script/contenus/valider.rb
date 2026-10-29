# frozen_string_literal: true

# Contrôle d'un fichier de leçon `lnclass.course-tree` v3 contre les règles de docs/contenus/prompt-redaction.md.
# Usage : ruby script/contenus/valider.rb fichier.json [fichier.json …]   (code de sortie 1 s'il y a une erreur)
# Ruby pur : ni Rails ni bundler. Les ERREURS reprennent les règles et les codes de raison de l'import v3
# (ADR fiche-de-revision-par-notion-et-figures-parametrees §4.1 et §4.2) : un fichier qui passe ici ne peut pas être refusé
# à l'import pour ces règles. Les AVERTISSEMENTS sont des conseils de rédaction que l'import ne contrôle pas.
require "json"
# Les bornes des figures sont lues dans le domaine (Ruby pur, sans Rails) : une seule source, les mêmes raisons qu'à l'import.
require_relative "../../app/domain/entities/catalog/figure_kinds"
require_relative "../../app/domain/entities/catalog/figure"

module Contenus
  class Valider
    LEVELS = %w[6ème 5ème 4ème 3ème 2nde 1ère Tle].freeze
    FIRST_CYCLE = %w[6ème 5ème 4ème 3ème].freeze
    MATERIALS = [ "Mathématiques", "Physique-Chimie", "SVT", "Français", "Histoire-Géographie", "Philosophie", "EDHC" ].freeze
    THEMES = %w[blue teal burgundy].freeze
    EXERCISE_TYPES = %w[fixation evaluation].freeze
    NOTIONS = (1..12)
    FIGURES = (0..12)
    METHOD_STEPS = (2..8)
    QUESTIONS = (5..30)
    EXPLANATION = (20..2_000)
    PROBLEMS = 4
    NOTION_TEXT_MAX = 1_200
    STEP_MAX = 300
    # type => [propositions autorisées, bonnes propositions]
    QUESTION_TYPES = {
      "true_false" => [ [ 2 ], 1 ], "single_choice" => [ [ 3, 4, 5 ], 1 ],
      "multiple_correct_2" => [ [ 4, 5 ], 2 ], "multiple_correct_3" => [ [ 5, 6 ], 3 ]
    }.freeze
    FORBIDDEN_WORDS = /habilet|notion cl[ée]|\bquiz\b|conforme au programme/i
    DEPENDENT = /question précédente|ci-dessus|figure ci|schéma ci|document ci/i
    STEP_CITATION = /(?:é|e)tape\s*\d/i
    HTML = %r{</?[a-zA-Z][^>]*>}

    attr_reader :errors, :warnings, :reasons

    def initialize(document)
      @document = document
      @errors = []
      @reasons = [] # [[chemin, code]] : ce que l'import écrirait dans son rapport
      @warnings = []
    end

    def call
      check
      self
    end

    private

    def check
      return fail_at("$", "format_invalid", "attendu : lnclass.course-tree version 3") unless @document.is_a?(Hash) && @document["format"] == "lnclass.course-tree"
      return fail_at("$", "format_retired", "version #{@document['version']} retirée : réécrire la leçon en version 3") if [ 1, 2 ].include?(@document["version"])
      return fail_at("$", "format_invalid", "version 3 attendue, trouvé #{@document['version'].inspect}") unless @document["version"] == 3

      courses = @document["courses"]
      return fail_at("courses", "invalid_count", "un fichier = un cours exactement") unless courses.is_a?(Array) && courses.size == 1
      return fail_at("courses[0]", "invalid_value", "objet attendu") unless courses.first.is_a?(Hash)

      course(courses.first)
    end

    def course(course)
      path = "courses[0]"
      plain_text(path, "name", course["name"], required: true)
      plain_text(path, "subtitle", course["subtitle"], required: true)
      warn_at("#{path}.subtitle", "attendu « Leçon N — progression DPFC 2026-2027 » pour une leçon de progression") unless course["subtitle"].to_s.match?(/\ALeçon \d+ — progression DPFC 2026-2027\z/)
      placement(path, course)
      theme = course["theme"]
      fail_at("#{path}.theme", "invalid_value", "blue, teal ou burgundy (ou absent), trouvé #{theme.inspect}") unless theme.nil? || THEMES.include?(theme)
      figures = figures(path, course["figures"])
      notions = course["notions"].is_a?(Array) ? course["notions"] : []
      fail_at("#{path}.notions", "invalid_count", "1 à 12 notions, trouvé #{notions.size}") unless NOTIONS.cover?(notions.size)
      duplicates(notions.map { it.is_a?(Hash) ? it["name"] : nil }).each { fail_at("#{path}.notions", "duplicate", "nom de notion répété : #{it}") }
      notions.each_with_index { |notion, i| notion(notion, "#{path}.notions[#{i}]", figures) }
      problems = course["exercises"].is_a?(Array) ? course["exercises"] : []
      fail_at("#{path}.exercises", "invalid_count", "#{PROBLEMS} problèmes exactement, trouvé #{problems.size}") unless problems.size == PROBLEMS
      problems.each_with_index { |problem, i| exercise(problem, "#{path}.exercises[#{i}]", figures, steps: nil) }
    end

    def placement(path, course)
      level, material, series = course.values_at("level_name", "material_name", "series_name")
      fail_at("#{path}.level_name", "invalid_value", "niveau inconnu : #{level.inspect}") unless LEVELS.include?(level)
      fail_at("#{path}.material_name", "invalid_value", "matière inconnue : #{material.inspect}") unless MATERIALS.include?(material)
      fail_at("#{path}.series_name", "invalid_value", "série à omettre au 1er cycle") if FIRST_CYCLE.include?(level) && series
      fail_at("#{path}.series_name", "invalid_value", "série obligatoire à partir de la 2nde") if LEVELS.include?(level) && !FIRST_CYCLE.include?(level) && series.to_s.empty? && material != "Histoire-Géographie"
      fail_at("#{path}.material_name", "invalid_value", "EDHC : 1er cycle seulement") if material == "EDHC" && !FIRST_CYCLE.include?(level)
      fail_at("#{path}.material_name", "invalid_value", "Philosophie : 1ère et Tle seulement") if material == "Philosophie" && !%w[1ère Tle].include?(level)
    end

    # → liste des clés de figures déclarées. Les contrôles de forme sont ceux de Entities::Catalog::Figure (même code qu'à l'import).
    def figures(path, raw)
      list = raw.nil? ? [] : raw
      return fail_at("#{path}.figures", "invalid_value", "liste attendue") && [] unless list.is_a?(Array)

      fail_at("#{path}.figures", "invalid_count", "0 à 12 figures, trouvé #{list.size}") unless FIGURES.cover?(list.size)
      list.each_with_index do |figure, i|
        Entities::Catalog::Figure.errors_for(figure).each do |sub_path, code, detail|
          fail_at("#{path}.figures[#{i}].#{sub_path}", code, "paramètre « #{detail[:param]} » hors règle (voir ADR §4.2)")
        end
      end
      list.each_with_index { |figure, i| control_targets(figure, "#{path}.figures[#{i}]") }
      keys = list.filter_map { it["key"] if it.is_a?(Hash) && it["key"].is_a?(String) }
      duplicates(keys).each { fail_at("#{path}.figures", "duplicate", "clé de figure répétée : #{it}") }
      keys
    end

    # Un curseur règle une clé numérique de premier niveau de `params` (conseil : l'import ne le contrôle pas encore).
    def control_targets(figure, path)
      return unless figure.is_a?(Hash) && figure["controls"].is_a?(Array) && figure["params"].is_a?(Hash)

      figure["controls"].each_with_index do |control, i|
        next unless control.is_a?(Hash) && !figure["params"][control["param"]].is_a?(Numeric)

        warn_at("#{path}.controls[#{i}].param", "« #{control['param']} » n'est pas une clé numérique de premier niveau de params (en geometry, utiliser des points draggable)")
      end
    end

    def notion(notion, path, figures)
      return fail_at(path, "invalid_value", "objet attendu") unless notion.is_a?(Hash)

      plain_text(path, "name", notion["name"], required: true)
      sheet(notion, path)
      figure_ref(notion["figure"], "#{path}.figure", figures)
      exercise = notion["exercise"]
      return fail_at("#{path}.exercise", "invalid_count", "un exercice exactement par notion, trouvé #{exercise.is_a?(Array) ? exercise.size : 0}") unless exercise.is_a?(Hash)

      exercise(exercise, "#{path}.exercise", figures, steps: Array(notion["method"]).grep(String))
    end

    # Gabarit des 4 blocs : mêmes règles et mêmes codes que Entities::Catalog::NotionSheet.errors_for.
    def sheet(notion, path)
      long_text("#{path}.remember", notion["remember"], NOTION_TEXT_MAX)
      long_text("#{path}.pitfall", notion["pitfall"], NOTION_TEXT_MAX)
      steps = notion["method"].is_a?(Array) ? notion["method"] : []
      fail_at("#{path}.method", "invalid_count", "2 à 8 étapes, trouvé #{steps.size}") unless METHOD_STEPS.cover?(steps.size)
      steps.each_with_index { |step, i| long_text("#{path}.method[#{i}]", step, STEP_MAX) }
      example = notion["example"].is_a?(Hash) ? notion["example"] : {}
      long_text("#{path}.example.statement", example["statement"], NOTION_TEXT_MAX)
      example_steps = example["steps"].is_a?(Array) ? example["steps"] : []
      fail_at("#{path}.example.steps", "example_steps_mismatch", "#{steps.size} étape(s) dans La méthode, #{example_steps.size} dans l'exemple corrigé") unless example_steps.size == steps.size
      example_steps.each_with_index { |step, i| long_text("#{path}.example.steps[#{i}]", step, STEP_MAX) }
    end

    def figure_ref(key, path, figures)
      return if key.nil?

      fail_at(path, "figure_missing", "figure « #{key} » absente de la leçon (clés : #{figures.join(', ')})") unless figures.include?(key)
    end

    def exercise(exercise, path, figures, steps:)
      return fail_at(path, "invalid_value", "objet attendu") unless exercise.is_a?(Hash)

      plain_text(path, "title", exercise["title"], required: true)
      fail_at("#{path}.statement", "blank", "énoncé obligatoire") if exercise["statement"].to_s.strip.empty?
      fail_at("#{path}.exercise_type", "invalid_value", "fixation ou evaluation attendu, trouvé #{exercise['exercise_type'].inspect}") unless EXERCISE_TYPES.include?(exercise["exercise_type"])
      figure_ref(exercise["figure"], "#{path}.figure", figures)
      questions = exercise["questions"].is_a?(Array) ? exercise["questions"] : []
      if questions.size < QUESTIONS.begin
        fail_at("#{path}.questions", "too_few_questions", "#{QUESTIONS.begin} questions au moins, trouvé #{questions.size}")
      elsif questions.size > QUESTIONS.end
        fail_at("#{path}.questions", "too_many_questions", "#{QUESTIONS.end} questions au plus, trouvé #{questions.size}")
      end
      questions.each_with_index { |question, i| question(question, "#{path}.questions[#{i}]", steps) }
      repeated = questions.filter_map { it["content"] if it.is_a?(Hash) }.tally.select { |_, n| n > 1 }.keys
      warn_at(path, "énoncé répété : #{repeated.first[0, 60]}…") if repeated.any?
    end

    def question(question, path, steps)
      return fail_at(path, "invalid_value", "objet attendu") unless question.is_a?(Hash)

      free_text(question["content"], "#{path}.content", 20_000)
      rules = QUESTION_TYPES[question["question_type"]]
      fail_at("#{path}.question_type", "unknown_type", "type inconnu : #{question['question_type'].inspect}") unless rules
      explanation(question["explanation"], path, steps)
      answers(question, path, rules) if rules
      warn_at(path, "dépend peut-être d'un élément absent") if question["content"].to_s.match?(DEPENDENT)
    end

    # La correction est obligatoire (20 à 2 000 caractères). Dans l'exercice d'une notion, elle doit reprendre la méthode.
    def explanation(value, path, steps)
      string = value.to_s
      where = "#{path}.explanation"
      if string.strip.empty? then fail_at(where, "blank", "correction obligatoire")
      elsif string.length < EXPLANATION.begin then fail_at(where, "too_short", "#{string.length} caractères (#{EXPLANATION.begin} au moins)")
      elsif string.length > EXPLANATION.end then fail_at(where, "too_long", "#{string.length} caractères (#{EXPLANATION.end} au plus)")
      end
      style(string, where)
      warn_at(where, "ne cite aucune étape de La méthode (« Étape n » ou les mots de l'étape) : la correction doit refaire la méthode") if steps && !string.strip.empty? && !cites_a_step?(string, steps)
    end

    def cites_a_step?(explanation, steps)
      return true if explanation.match?(STEP_CITATION)

      text = normalize(explanation)
      steps.any? do |step|
        words = normalize(step).split.first(3)
        words.size >= 2 && text.include?(words.join(" "))
      end
    end

    def normalize(string) = string.downcase.delete("$*").gsub(/\s+/, " ").strip

    # Structure d'ADR-0115 (Entities::Assessment::QuestionKinds::Choice) : mêmes codes qu'à l'import.
    # Les fourchettes du prompt (3 à 5 propositions, etc.) sont un conseil, pas un refus.
    def answers(question, path, (counts, good))
      answers = question["answers"].is_a?(Array) ? question["answers"].grep(Hash) : []
      type = question["question_type"]
      fail_at("#{path}.answers", "true_false_needs_two_answers", "Vrai/Faux : 2 propositions, trouvé #{answers.size}") if type == "true_false" && answers.size != 2
      fail_at("#{path}.answers", "too_few_answers", "au moins #{good + 1} propositions, trouvé #{answers.size}") if type != "true_false" && answers.size <= good
      correct = answers.count { it["correct"] == true }
      fail_at("#{path}.answers", "wrong_correct_count", "#{good} bonne(s) proposition(s) attendue(s), trouvé #{correct}") unless correct == good
      warn_at("#{path}.answers", "#{counts.join(' ou ')} propositions conseillées pour ce type, trouvé #{answers.size}") unless counts.include?(answers.size)
      if type == "true_false" && answers.map { it["content"] }.sort != %w[Faux Vrai]
        warn_at("#{path}.answers", "Vrai/Faux : propositions « Vrai » et « Faux » exactement")
      end
      answers.each_with_index do |answer, i|
        fail_at("#{path}.answers[#{i}].content", "blank", "proposition vide") if answer["content"].to_s.strip.empty?
        free_text(answer["content"], "#{path}.answers[#{i}].content", 500)
      end
      warn_at("#{path}.answers", "deux propositions identiques") if answers.map { it["content"] }.uniq.size != answers.size
    end

    # Bloc d'une notion : obligatoire, longueur bornée (mêmes codes blank / too_long que NotionSheet).
    def long_text(path, value, max)
      if !value.is_a?(String) || value.strip.empty? then fail_at(path, "blank", "texte obligatoire")
      elsif value.length > max then fail_at(path, "too_long", "#{value.length} caractères (#{max} au plus)")
      end
      style(value.to_s, path)
    end

    # Énoncés et propositions des questions : longueur bornée.
    def free_text(value, path, max)
      string = value.to_s
      fail_at(path, "too_long", "#{string.length} caractères (#{max} au plus)") if string.length > max
      style(string, path)
    end

    # Noms, sous-titres, titres : 150 caractères, pas de formule (KaTeX n'y est pas rendu).
    def plain_text(path, key, value, required: false)
      string = value.to_s
      fail_at("#{path}.#{key}", "blank", "obligatoire") if required && string.strip.empty?
      fail_at("#{path}.#{key}", "too_long", "#{string.length} caractères (150 au plus)") if string.length > 150
      warn_at("#{path}.#{key}", "pas de formule ($ ou \\) dans ce champ : elle n'y est pas rendue") if string.match?(/[$\\]/)
      vocabulary(string, "#{path}.#{key}")
    end

    # Conseils de rédaction : le rendu échappe tout (pas de HTML, pas de [[…]]), les mots interdits ne sont pas refusés à l'import.
    def style(string, path)
      warn_at(path, "pas de HTML ni de [[…]] : seul le balisage $…$, **gras**, *italique* est rendu") if string.match?(HTML) || string.include?("[[")
      warn_at(path, "\\ce{…} n'est pas disponible") if string.include?("\\ce{")
      vocabulary(string, path)
    end

    def vocabulary(string, path)
      found = string[FORBIDDEN_WORDS]
      warn_at(path, "vocabulaire interdit : « #{found} »") if found
    end

    def duplicates(values) = values.compact.tally.select { |_, n| n > 1 }.keys

    def fail_at(path, code, detail = nil)
      @reasons << [ path, code ]
      @errors << "#{path} : #{code}#{" — #{detail}" if detail}"
      nil
    end

    def warn_at(path, message) = @warnings << "#{path} : #{message}"
  end
end

if $PROGRAM_NAME == __FILE__
  files = ARGV
  abort "Usage : ruby script/contenus/valider.rb fichier.json […]" if files.empty?
  failed = files.count do |file|
    document = begin
      JSON.parse(File.read(file, encoding: "UTF-8"))
    rescue JSON::ParserError, SystemCallError => e
      puts "✗ #{file}\n    JSON illisible : #{e.message[0, 120]}"
      next true
    end
    result = Contenus::Valider.new(document).call
    puts "#{result.errors.empty? ? '✓' : '✗'} #{file}"
    result.errors.first(30).each { |message| puts "    ERREUR #{message}" }
    puts "    … #{result.errors.size - 30} autres erreurs" if result.errors.size > 30
    result.warnings.each { |message| puts "    avertissement #{message}" }
    !result.errors.empty?
  end
  exit(failed.zero? ? 0 : 1)
end
