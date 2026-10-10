# frozen_string_literal: true

# Contrôle d'un fichier de leçon `lnclass.course-tree` contre les règles de docs/contenus/prompt-redaction.md.
# Usage : ruby script/contenus/valider.rb fichier.json [fichier.json …]   (code de sortie 1 s'il y a une erreur)
# Ruby pur : ni Rails ni bundler. L'import refait ses propres contrôles ; celui-ci évite de les découvrir après coup.
require "json"

module Contenus
  class Valider
    LEVELS = %w[6ème 5ème 4ème 3ème 2nde 1ère Tle].freeze
    FIRST_CYCLE = %w[6ème 5ème 4ème 3ème].freeze
    MATERIALS = [ "Mathématiques", "Physique-Chimie", "SVT", "Français", "Histoire-Géographie", "Philosophie", "EDHC" ].freeze
    SECTIONS = [ "Ce que tu vas savoir faire", "L'image pour comprendre", "Ce qu'il faut retenir", "Exemple résolu",
                 "Le piège à éviter", "En une phrase" ].freeze
    TAGS = %w[h2 h3 p ul ol li strong em blockquote].freeze
    EXERCISES = [ [ "Comprendre", "fixation" ], [ "Appliquer", "fixation" ], [ "S'évaluer", "evaluation" ] ].freeze
    # type => [propositions autorisées, bonnes propositions]
    QUESTION_TYPES = {
      "true_false" => [ [ 2 ], 1 ], "single_choice" => [ [ 3, 4, 5 ], 1 ],
      "multiple_correct_2" => [ [ 4, 5 ], 2 ], "multiple_correct_3" => [ [ 5, 6 ], 3 ]
    }.freeze
    FORBIDDEN_WORDS = /habilet|notion cl[ée]|\bquiz\b|conforme au programme/i
    DEPENDENT = /question précédente|ci-dessus|figure ci|schéma ci|document ci/i

    attr_reader :errors, :warnings

    def initialize(document)
      @document = document
      @errors = []
      @warnings = []
    end

    def call
      return fail_at("$", "format attendu lnclass.course-tree v1") unless @document.is_a?(Hash) &&
        @document["format"] == "lnclass.course-tree" && @document["version"] == 1
      courses = @document["courses"]
      return fail_at("courses", "un fichier = un cours exactement") unless courses.is_a?(Array) && courses.size == 1

      course(courses.first)
      self
    end

    private

    def course(course)
      path = "courses[0]"
      plain_text(path, "name", course["name"], required: true)
      plain_text(path, "subtitle", course["subtitle"], required: true)
      unless course["subtitle"].to_s.match?(/\ALeçon \d+ — progression DPFC 2026-2027\z/)
        fail_at("#{path}.subtitle", "attendu « Leçon N — progression DPFC 2026-2027 »")
      end
      placement(path, course)
      essentials = Array(course["essentials"])
      fail_at("#{path}.essentials", "2 à 5 fiches essentielles, trouvé #{essentials.size}") unless (2..5).cover?(essentials.size)
      essentials.each_with_index { |essential, i| essential(essential, "#{path}.essentials[#{i}]") }
    end

    def placement(path, course)
      level, material, series = course.values_at("level_name", "material_name", "series_name")
      fail_at("#{path}.level_name", "niveau inconnu : #{level.inspect}") unless LEVELS.include?(level)
      fail_at("#{path}.material_name", "matière inconnue : #{material.inspect}") unless MATERIALS.include?(material)
      fail_at("#{path}.series_name", "série à omettre au 1er cycle") if FIRST_CYCLE.include?(level) && series
      fail_at("#{path}.series_name", "série obligatoire à partir de la 2nde") if !FIRST_CYCLE.include?(level) && series.to_s.empty?
      fail_at("#{path}.material_name", "EDHC : 1er cycle seulement") if material == "EDHC" && !FIRST_CYCLE.include?(level)
      fail_at("#{path}.material_name", "Philosophie : 1ère et Tle seulement") if material == "Philosophie" && !%w[1ère Tle].include?(level)
    end

    def essential(essential, path)
      plain_text(path, "name", essential["name"], required: true)
      plain_text(path, "subtitle", essential["subtitle"], required: true)
      content(essential["content"].to_s, "#{path}.content")
      exercises = Array(essential["exercises"])
      return fail_at("#{path}.exercises", "3 exercices attendus, trouvé #{exercises.size}") unless exercises.size == 3

      exercises.each_with_index { |exercise, i| exercise(exercise, "#{path}.exercises[#{i}]", EXERCISES[i]) }
    end

    def content(html, path)
      fail_at(path, "contenu vide") if html.strip.empty?
      (html.scan(%r{</?([a-zA-Z][a-zA-Z0-9]*)}).flatten.map(&:downcase).uniq - TAGS).each do |tag|
        fail_at(path, "balise <#{tag}> non autorisée (supprimée à l'import)")
      end
      titles = html.scan(%r{<h2>(.*?)</h2>}m).flatten.map { |title| title.gsub(/<[^>]+>/, "").strip }
      fail_at(path, "sections h2 attendues dans l'ordre : #{SECTIONS.join(' · ')} ; trouvé : #{titles.join(' · ')}") unless titles == SECTIONS
      fail_at(path, "« Ce qu'il faut retenir » doit être dans un <blockquote>") unless html.include?("<blockquote")
      fail_at(path, "\\ce{…} n'est pas disponible") if html.include?("\\ce{")
      vocabulary(html, path)
    end

    def exercise(exercise, path, (role, type))
      title = exercise["title"].to_s
      plain_text(path, "title", title, required: true)
      fail_at("#{path}.title", "doit commencer par « #{role} — »") unless title.start_with?("#{role} — ")
      fail_at("#{path}.exercise_type", "#{type} attendu, trouvé #{exercise['exercise_type'].inspect}") unless exercise["exercise_type"] == type
      questions = Array(exercise["questions"])
      fail_at("#{path}.questions", "5 à 6 questions, trouvé #{questions.size}") unless (5..6).cover?(questions.size)
      questions.each_with_index { |question, i| question(question, "#{path}.questions[#{i}]") }
      repeated = questions.map { |question| question["content"] }.tally.select { |_, n| n > 1 }.keys
      warn_at(path, "énoncé répété : #{repeated.first[0, 60]}…") if repeated.any?
    end

    def question(question, path)
      text(question["content"], "#{path}.content", 20_000)
      rules = QUESTION_TYPES[question["question_type"]]
      return fail_at("#{path}.question_type", "type inconnu : #{question['question_type'].inspect}") unless rules

      explanation = question["explanation"].to_s
      fail_at("#{path}.explanation", "explication obligatoire") if explanation.strip.empty?
      # 400 est une règle du prompt (explication courte sur téléphone), pas une limite de l’application : avertissement.
      warn_at("#{path}.explanation", "#{explanation.size} caractères (400 au plus)") if explanation.size > 400
      text(explanation, "#{path}.explanation", 5_000)
      answers(question, path, rules)
      warn_at(path, "dépend peut-être d'un élément absent") if question["content"].to_s.match?(DEPENDENT)
    end

    def answers(question, path, (counts, good))
      answers = Array(question["answers"])
      fail_at("#{path}.answers", "#{counts.join(' ou ')} propositions attendues, trouvé #{answers.size}") unless counts.include?(answers.size)
      correct = answers.count { |answer| answer["correct"] == true }
      fail_at("#{path}.answers", "#{good} bonne(s) proposition(s) attendue(s), trouvé #{correct}") unless correct == good
      if question["question_type"] == "true_false" && answers.map { |answer| answer["content"] }.sort != %w[Faux Vrai]
        fail_at("#{path}.answers", "Vrai/Faux : propositions « Vrai » et « Faux » exactement")
      end
      answers.each_with_index do |answer, i|
        text(answer["content"], "#{path}.answers[#{i}].content", 500)
        fail_at("#{path}.answers[#{i}].content", "proposition vide") if answer["content"].to_s.strip.empty?
      end
      fail_at("#{path}.answers", "deux propositions identiques") if answers.map { |answer| answer["content"] }.uniq.size != answers.size
    end

    # Texte brut des questions : pas de HTML, longueur bornée.
    def text(value, path, max)
      string = value.to_s
      fail_at(path, "pas de HTML dans ce champ") if string.match?(%r{</?[a-zA-Z][^>]*>})
      fail_at(path, "#{string.size} caractères (#{max} au plus)") if string.size > max
      vocabulary(string, path)
    end

    # Noms, sous-titres, titres : 150 caractères, pas de formule (KaTeX n'y est pas rendu).
    def plain_text(path, key, value, required: false)
      string = value.to_s
      fail_at("#{path}.#{key}", "obligatoire") if required && string.strip.empty?
      fail_at("#{path}.#{key}", "#{string.size} caractères (150 au plus)") if string.size > 150
      fail_at("#{path}.#{key}", "pas de formule ($ ou \\) dans ce champ") if string.match?(/[$\\]/)
      vocabulary(string, "#{path}.#{key}")
    end

    def vocabulary(string, path)
      found = string[FORBIDDEN_WORDS]
      fail_at(path, "vocabulaire interdit : « #{found} »") if found
    end

    def fail_at(path, message)
      @errors << "#{path} : #{message}"
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
