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
      @schema = [] # fautes que le schéma JSON de l'import refuse en premier : il rend alors le seul code « schema »
      @adapter = [] # fautes que l'adaptateur de l'import note à leur raison propre
      @errors = []
      @reasons = [] # [[chemin, code]] : ce que l'import écrirait dans son rapport
      @warnings = []
    end

    # Comme l'import : si le schéma refuse la leçon, l'adaptateur ne la lit pas, et le rapport ne contient que les erreurs « schema ».
    def call
      check
      escapes(@document, "$")
      found = @schema.empty? ? @adapter : @schema
      @reasons = found.map { |path, code, _| [ path, code ] }
      @errors = found.map { |path, code, detail| "#{path} : #{code}#{" — #{detail}" if detail}" }
      self
    end

    private

    # Un \n, \t, \f, \b ou \r du JSON coupe une commande LaTeX (\neq, \times, \frac, \beta, \rho) : le texte reçoit un
    # caractère de contrôle et la formule est cassée. L'import ne le refuse pas, le script le signale (relecture leçon 2).
    LATEX_BREAK = /[\x00-\x08\x0b-\x1f]|[\n\t](?=[a-z]{2})/

    def escapes(node, path)
      case node
      when Hash then node.each { |key, value| escapes(value, "#{path}.#{key}") }
      when Array then node.each_with_index { |value, index| escapes(value, "#{path}[#{index}]") }
      when String then warn_at(path.delete_prefix("$."), "caractère de contrôle : commande LaTeX à doubler (\\\\neq, \\\\frac, \\\\times)") if node.match?(LATEX_BREAK)
      end
    end

    def check
      return fail_at("format", "format_mismatch", "attendu : lnclass.course-tree version 3") unless @document.is_a?(Hash) && @document["format"] == "lnclass.course-tree"
      return fail_at("version", "format_retired", "version #{@document['version']} retirée : réécrire la leçon en version 3") if [ 1, 2 ].include?(@document["version"])
      return fail_at("version", "version_unsupported", "version 3 attendue, trouvé #{@document['version'].inspect}") unless @document["version"] == 3

      courses = @document["courses"]
      return schema_at("courses", "liste attendue") unless courses.is_a?(Array)

      warn_at("courses", "un fichier = un cours : les règles de rédaction visent une leçon par fichier") unless courses.size == 1
      courses.each_with_index { |course, i| course(course, "courses[#{i}]") }
    end

    def course(course, path)
      return schema_at(path, "objet attendu") unless course.is_a?(Hash)

      text(path, "name", course["name"], schema_max: 200, max: 200, required: true)
      text(path, "subtitle", course["subtitle"], schema_max: 300, max: 150)
      warn_at("#{path}.subtitle", "attendu « Leçon N — progression DPFC 2026-2027 » pour une leçon de progression") unless course["subtitle"].to_s.match?(/\ALeçon \d+ — progression DPFC 2026-2027\z/)
      placement(path, course)
      theme = course["theme"]
      schema_at("#{path}.theme", "blue, teal ou burgundy (ou absent), trouvé #{theme.inspect}") unless !course.key?("theme") || THEMES.include?(theme)
      figures = figures(path, course["figures"])
      notions = course["notions"]
      if notions.is_a?(Array)
        schema_at("#{path}.notions", "1 à 12 notions, trouvé #{notions.size}") unless NOTIONS.cover?(notions.size)
      else
        schema_at("#{path}.notions", "liste attendue")
        notions = []
      end
      repeated_notions(notions, path)
      notions.each_with_index { |notion, i| notion(notion, "#{path}.notions[#{i}]", figures, course["name"]) }
      problems = course["exercises"]
      if problems.is_a?(Array)
        fail_at("#{path}.exercises", "lesson_exercise_count", "#{PROBLEMS} problèmes exactement, trouvé #{problems.size}") unless problems.size == PROBLEMS
      else
        schema_at("#{path}.exercises", "liste attendue")
        problems = []
      end
      problems.each_with_index { |problem, i| exercise(problem, "#{path}.exercises[#{i}]", figures, steps: nil) }
    end

    # Le niveau et la matière inconnus sont refusés comme à l'import (unknown_level, unknown_material). Le reste du placement
    # (séries, Philosophie, EDHC) dépend de la base : l'import le contrôle, le script le signale seulement.
    def placement(path, course)
      level, material, series = course.values_at("level_name", "material_name", "series_name")
      text(path, "level_name", level, schema_max: 100, max: 100, required: true)
      text(path, "material_name", material, schema_max: 100, max: 100, required: true)
      text(path, "series_name", series, schema_max: 100, max: 100)
      fail_at("#{path}.level_name", "unknown_level", "niveau inconnu : #{level.inspect}") if level.is_a?(String) && !level.empty? && !LEVELS.include?(level)
      fail_at("#{path}.material_name", "unknown_material", "matière inconnue : #{material.inspect}") if material.is_a?(String) && !material.empty? && !MATERIALS.include?(material)
      warn_at("#{path}.series_name", "série à omettre au 1er cycle (l'import la refuse si elle n'est pas liée au niveau)") if FIRST_CYCLE.include?(level) && series
      warn_at("#{path}.series_name", "série attendue à partir de la 2nde") if LEVELS.include?(level) && !FIRST_CYCLE.include?(level) && series.to_s.empty? && material != "Histoire-Géographie"
      warn_at("#{path}.material_name", "EDHC : 1er cycle seulement") if material == "EDHC" && !FIRST_CYCLE.include?(level)
      warn_at("#{path}.material_name", "Philosophie : 1ère et Tle seulement") if material == "Philosophie" && !%w[1ère Tle].include?(level)
    end

    # → liste des clés de figures déclarées. Les contrôles de forme sont ceux de Entities::Catalog::Figure (même code qu'à l'import).
    def figures(path, raw)
      list = raw.nil? ? [] : raw
      return schema_at("#{path}.figures", "liste attendue") && [] unless list.is_a?(Array)

      schema_at("#{path}.figures", "0 à 12 figures, trouvé #{list.size}") unless FIGURES.cover?(list.size)
      list.each_with_index do |figure, i|
        figure_path = "#{path}.figures[#{i}]"
        unless figure.is_a?(Hash) && %w[key kind description params].all? { figure.key?(it) } && figure["params"].is_a?(Hash) &&
               %w[key kind description].all? { figure[it].is_a?(String) } && (figure["controls"].nil? || figure["controls"].is_a?(Array))
          schema_at(figure_path, "figure mal formée : key, kind, description, params attendus")
          next
        end
        Entities::Catalog::Figure.errors_for(figure).each do |sub_path, code, detail|
          fail_at(sub_path == "$" ? figure_path : "#{figure_path}.#{sub_path}", code, "paramètre « #{detail[:param]} » hors règle (voir ADR §4.2)")
        end
      end
      seen = []
      list.each_with_index do |figure, i|
        key = figure["key"] if figure.is_a?(Hash)
        next unless key.is_a?(String)

        fail_at("#{path}.figures[#{i}].key", "figure_invalid", "clé de figure répétée : #{key}") if seen.include?(key)
        seen << key
      end
      list.filter_map { it["key"] if it.is_a?(Hash) && it["key"].is_a?(String) }
    end

    # L'import note la seconde notion de même nom (casse, accents et espaces ignorés) à son propre chemin.
    def repeated_notions(notions, path)
      seen = []
      notions.each_with_index do |notion, i|
        next unless notion.is_a?(Hash)

        name = notion["name"].to_s.gsub(/\s+/, " ").strip.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
        next if name.empty?

        fail_at("#{path}.notions[#{i}].name", "invalid_value", "nom de notion répété : #{notion['name']}") if seen.include?(name)
        seen << name
      end
    end

    def notion(notion, path, figures, course_name)
      return schema_at(path, "objet attendu") unless notion.is_a?(Hash)

      text(path, "name", notion["name"], schema_max: 200, max: 150, required: true)
      sheet(notion, path)
      figure_ref(notion["figure"], "#{path}.figure", figures)
      exercise = notion["exercise"]
      return exercise(exercise, "#{path}.exercise", figures, steps: Array(notion["method"]).grep(String)) if exercise.is_a?(Hash)

      count = exercise.is_a?(Array) ? exercise.size : 0
      fail_at("#{path}.exercise", "essential_exercise_count", "un exercice exactement par notion, trouvé #{count}")
    end

    # Gabarit des 4 blocs : le schéma refuse les bornes de taille (« schema »), l'entité NotionSheet le reste (blank, too_long,
    # example_steps_mismatch).
    def sheet(notion, path)
      long_text("#{path}.remember", notion["remember"], NOTION_TEXT_MAX)
      long_text("#{path}.pitfall", notion["pitfall"], NOTION_TEXT_MAX)
      steps = step_list("#{path}.method", notion["method"])
      example = notion["example"]
      unless example.is_a?(Hash)
        schema_at("#{path}.example", "objet attendu")
        example = {}
      end
      long_text("#{path}.example.statement", example["statement"], NOTION_TEXT_MAX)
      example_steps = step_list("#{path}.example.steps", example["steps"])
      return unless METHOD_STEPS.cover?(steps.size) && METHOD_STEPS.cover?(example_steps.size)

      fail_at("#{path}.example.steps", "example_steps_mismatch", "#{steps.size} étape(s) dans La méthode, #{example_steps.size} dans l'exemple corrigé") unless example_steps.size == steps.size
    end

    def step_list(path, value)
      return schema_at(path, "liste de 2 à 8 étapes attendue") && [] unless value.is_a?(Array)

      schema_at(path, "2 à 8 étapes, trouvé #{value.size}") unless METHOD_STEPS.cover?(value.size)
      value.each_with_index { |step, i| long_text("#{path}[#{i}]", step, STEP_MAX) }
      value
    end

    def figure_ref(key, path, figures)
      return if key.nil? || key.to_s.empty?
      return schema_at(path, "clé de figure : minuscules, chiffres et tirets (40 au plus)") unless key.is_a?(String) && key.match?(/\A[a-z0-9][a-z0-9-]{0,39}\z/)

      fail_at(path, "figure_missing", "figure « #{key} » absente de la leçon (clés : #{figures.join(', ')})") unless figures.include?(key)
    end

    def exercise(exercise, path, figures, steps:)
      return schema_at(path, "objet attendu") unless exercise.is_a?(Hash)

      text(path, "title", exercise["title"], schema_max: 200, max: 150, required: true)
      statement = exercise["statement"]
      if !statement.is_a?(String) || statement.empty? || statement.length > 5_000 then schema_at("#{path}.statement", "énoncé obligatoire, 5 000 caractères au plus")
      elsif statement.strip.empty? then fail_at("#{path}.statement", "blank", "énoncé obligatoire")
      end
      type = exercise["exercise_type"]
      if !type.is_a?(String) || type.empty? || type.length > 40 then schema_at("#{path}.exercise_type", "texte de 1 à 40 caractères attendu")
      elsif !EXERCISE_TYPES.include?(type) then fail_at("#{path}.exercise_type", "invalid_value", "fixation ou evaluation attendu, trouvé #{type.inspect}")
      end
      figure_ref(exercise["figure"], "#{path}.figure", figures)
      questions = exercise["questions"]
      schema_at("#{path}.questions", "liste attendue") if !questions.nil? && !questions.is_a?(Array)
      questions = questions.is_a?(Array) ? questions : []
      if questions.size < QUESTIONS.begin
        fail_at("#{path}.questions", "too_few_questions", "#{QUESTIONS.begin} questions au moins, trouvé #{questions.size}")
      elsif questions.size > QUESTIONS.end
        fail_at("#{path}.questions", "invalid_count", "#{QUESTIONS.end} questions au plus, trouvé #{questions.size}")
      end
      questions.each_with_index { |question, i| question(question, "#{path}.questions[#{i}]", steps) }
      repeated = questions.filter_map { it["content"] if it.is_a?(Hash) }.tally.select { |_, n| n > 1 }.keys
      warn_at(path, "énoncé répété : #{repeated.first.to_s[0, 60]}…") if repeated.any?
    end

    def question(question, path, steps)
      return schema_at(path, "objet attendu") unless question.is_a?(Hash)

      content = question["content"]
      if !content.is_a?(String) || content.empty? || content.length > 2_000 then schema_at("#{path}.content", "énoncé de 1 à 2 000 caractères attendu")
      elsif content.strip.empty? then fail_at("#{path}.content", "blank", "énoncé vide")
      end
      style(content.to_s, "#{path}.content")
      type = question["question_type"]
      rules = QUESTION_TYPES[type]
      if !type.is_a?(String) || type.empty? || type.length > 40 then schema_at("#{path}.question_type", "texte de 1 à 40 caractères attendu")
      elsif rules.nil? then fail_at("#{path}.question_type", "invalid_value", "type inconnu : #{type.inspect}")
      end
      explanation(question["explanation"], path, steps)
      raw_answers = question["answers"]
      return schema_at("#{path}.answers", "liste de 10 propositions au plus attendue") unless raw_answers.is_a?(Array) && raw_answers.size <= 10

      answers(question, raw_answers, path, rules) if rules
      warn_at(path, "dépend peut-être d'un élément absent") if question["content"].to_s.match?(DEPENDENT)
    end

    # La correction est obligatoire (20 à 2 000 caractères, espaces réduits). Dans l'exercice d'une notion, elle doit reprendre la méthode.
    def explanation(value, path, steps)
      where = "#{path}.explanation"
      return schema_at(where, "texte attendu") unless value.nil? || value.is_a?(String)

      string = value.to_s.gsub(/\s+/, " ").strip
      if string.empty? then fail_at(where, "blank", "correction obligatoire")
      elsif string.length < EXPLANATION.begin then fail_at(where, "too_short", "#{string.length} caractères (#{EXPLANATION.begin} au moins)")
      elsif string.length > EXPLANATION.end then fail_at(where, "too_long", "#{string.length} caractères (#{EXPLANATION.end} au plus)")
      end
      style(string, where)
      warn_at(where, "ne cite aucune étape de La méthode (« Étape n » ou les mots de l'étape) : la correction doit refaire la méthode") if steps && !string.empty? && !cites_a_step?(string, steps)
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

    def normalize(string) = string.downcase.delete("$*").gsub(/\s+/, " ").strip

    # Structure d'ADR-0115 (Entities::Catalog::ContentNode) : l'import rend « question_structure » pour toute faute de propositions.
    # Les fourchettes du prompt (3 à 5 propositions, etc.) sont un conseil, pas un refus.
    def answers(question, raw_answers, path, (counts, good))
      return schema_at("#{path}.answers", "propositions : objets attendus") unless raw_answers.all?(Hash)

      answers = raw_answers
      type = question["question_type"]
      structure = []
      structure << "Vrai/Faux : 2 propositions, trouvé #{answers.size}" if type == "true_false" && answers.size != 2
      structure << "au moins #{good + 1} propositions, trouvé #{answers.size}" if type != "true_false" && answers.size <= good
      correct = answers.count { it["correct"] == true || (!it.key?("correct") && it["is_correct"] == true) }
      structure << "#{good} bonne(s) proposition(s) attendue(s), trouvé #{correct}" unless correct == good
      fail_at("#{path}.answers", "question_structure", structure.join(" ; ")) if structure.any?
      warn_at("#{path}.answers", "#{counts.join(' ou ')} propositions conseillées pour ce type, trouvé #{answers.size}") unless counts.include?(answers.size)
      if type == "true_false" && answers.map { it["content"] }.sort != %w[Faux Vrai]
        warn_at("#{path}.answers", "Vrai/Faux : propositions « Vrai » et « Faux » exactement")
      end
      answers.each_with_index do |answer, i|
        content = answer["content"]
        if !content.nil? && !content.is_a?(String) || content.to_s.length > 500 then schema_at("#{path}.answers[#{i}].content", "texte de 500 caractères au plus attendu")
        elsif content.to_s.strip.empty? then fail_at("#{path}.answers[#{i}].content", "blank", "proposition vide")
        end
        style(content.to_s, "#{path}.answers[#{i}].content")
      end
      warn_at("#{path}.answers", "deux propositions identiques") if answers.map { it["content"] }.uniq.size != answers.size
    end

    # Bloc d'une notion : le schéma impose 1 à `max` caractères ; une valeur faite d'espaces est « blank » (NotionSheet).
    def long_text(path, value, max)
      if !value.is_a?(String) || value.empty? || value.length > max then schema_at(path, "texte de 1 à #{max} caractères attendu")
      elsif value.strip.empty? then fail_at(path, "blank", "texte obligatoire")
      end
      style(value.to_s, path)
    end

    # Noms, sous-titres, titres : le schéma borne la taille brute (schema_max), l'adaptateur la taille réduite (max, « too_long »).
    # Pas de formule (KaTeX n'y est pas rendu).
    def text(path, key, value, schema_max:, max:, required: false)
      where = "#{path}.#{key}"
      if value.nil? && !required then return
      elsif !value.is_a?(String) || (required && value.empty?) || value.length > schema_max then return schema_at(where, "texte attendu, #{schema_max} caractères au plus")
      end

      squished = value.gsub(/\s+/, " ").strip
      if squished.empty? && required then fail_at(where, "blank", "obligatoire")
      elsif squished.length > max then fail_at(where, "too_long", "#{squished.length} caractères (#{max} au plus)")
      end
      warn_at(where, "pas de formule ($ ou \\) dans ce champ : elle n'y est pas rendue") if value.match?(/[$\\]/)
      vocabulary(value, where)
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

    def schema_at(path, detail = nil)
      @schema << [ path, "schema", detail ]
      nil
    end

    def fail_at(path, code, detail = nil)
      @adapter << [ path, code, detail ]
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
