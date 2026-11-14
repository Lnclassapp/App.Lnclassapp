# frozen_string_literal: true

# Extrait les corrections du validateur pédagogique (Avant → Après) des leçons listées dans a-reporter-en-production.md, en comparant
# chaque fichier à sa version d'avant la correction (commit donné). Écrit docs/chantiers/corrections-production/corrections.json,
# lu par `bin/rails contenus:corriger`. Hors production : lit l'historique git.
# Usage : ruby script/contenus/extraire_corrections.rb [<commit d'avant>]   (défaut : f712f8b45^)
# Ruby pur. Un écart qu'aucun use case ne sait écrire (entraînement de notion, figure, structure) est écrit « hors_perimetre ».
require "json"
require "open3"
require "pathname"

module Contenus
  class ExtraireCorrections
    ROOT = Pathname(__dir__).join("../..").expand_path
    LIST = ROOT.join("docs/chantiers/validation-pedagogique-agent/a-reporter-en-production.md")
    OUTPUT = ROOT.join("docs/chantiers/corrections-production/corrections.json")
    DEFAULT_BEFORE = "f712f8b45^"
    FIELD = /(?<field>title|statement|hint)\z/
    EXERCISE = /\A(?<owner>notions\[(?<notion>\d+)\]\.exercise(?:\[(?<n>\d+)\])?|exercises\[(?<problem>\d+)\]|subjects\[(?<subject>\d+)\]\.exercises\[(?<n2>\d+)\])\.(?<rest>.+)\z/
    NOTION = /\Anotions\[(?<notion>\d+)\]\.(?<field>name|remember|pitfall|method\[\d+\]|example\.statement|example\.steps\[\d+\])\z/
    QUESTION = /\Aquestions\[(?<question>\d+)\]\.(?:(?<qfield>content|explanation|hint)|answers\[(?<answer>\d+)\]\.(?<afield>content|correct|match))\z/

    def self.run(argv, out: $stdout)
      before = argv.first || DEFAULT_BEFORE
      new(before:, out:).call
    end

    def initialize(before: DEFAULT_BEFORE, out: $stdout)
      @before = before
      @out = out
    end

    def call
      files = LIST.read.scan(%r{docs/contenus/lecons-traitees/[\w./-]+\.json}).uniq.sort
      lessons = files.filter_map { lesson(it) }
      OUTPUT.write(JSON.pretty_generate({ "avant" => @before, "lessons" => lessons }) << "\n")
      counts = lessons.flat_map { it["changes"] }.group_by { it["kind"] }.transform_values(&:size)
      @out.puts "#{lessons.size} leçon(s) modifiée(s) sur #{files.size} listée(s) ; #{counts.to_json}"
      0
    end

    private

    def lesson(file)
      old = git_json("#{@before}:#{file}")
      new = JSON.parse(ROOT.join(file).read)
      return unless old && new

      old_course = old.fetch("courses").first
      new_course = new.fetch("courses").first
      changes = diff(flat(old_course), flat(new_course)).map { classify(it, old_course) }
      return if changes.empty?

      identity = new_course.slice("name", "level_name", "material_name", "series_name")
      { "file" => file.delete_prefix("docs/contenus/lecons-traitees/"), "course" => identity, "changes" => changes }
    end

    def git_json(spec)
      content, status = Open3.capture2("git", "-C", ROOT.to_s, "show", spec, err: File::NULL)
      status.success? ? JSON.parse(content) : nil
    end

    # { "notions[0].exercise[1].questions[0].content" => "…" }, les figures exclues (aucun use case ne les écrit).
    def flat(node, path = nil, into = {})
      case node
      when Hash then node.each { |key, value| flat(value, [ path, key ].compact.join("."), into) unless path.nil? && key == "figures" }
      when Array then node.each_with_index { |value, index| flat(value, "#{path}[#{index}]", into) }
      else into[path] = node
      end
      into
    end

    def diff(old, new) = (old.keys | new.keys).filter_map { |path| [ path, old[path], new[path] ] unless old[path] == new[path] }

    def classify((path, avant, apres), _course)
      base = { "path" => path, "avant" => avant, "apres" => apres }
      if (notion = NOTION.match(path))
        base.merge("kind" => "notion", "notion" => notion[:notion].to_i, "field" => notion[:field])
      elsif (exercise = EXERCISE.match(path))
        exercise_change(base, exercise)
      else
        base.merge("kind" => "hors_perimetre")
      end
    end

    def exercise_change(base, match)
      rest = match[:rest]
      place = if match[:notion] then { "group" => "notion", "notion" => match[:notion].to_i, "exercise" => match[:n].to_i }
      elsif match[:problem] then { "group" => "problem", "exercise" => match[:problem].to_i }
      else { "group" => "subject", "subject" => match[:subject].to_i, "exercise" => match[:n2].to_i }
      end
      if rest.match?(/\A(title|statement|hint)\z/)
        base.merge("kind" => "exercise", "field" => rest, **place)
      elsif (question = QUESTION.match(rest))
        base.merge("kind" => "exercise", "question" => question[:question].to_i, "field" => question[:qfield] || question[:afield],
                   **(question[:answer] ? { "answer" => question[:answer].to_i } : {}), **place)
      else
        base.merge("kind" => "hors_perimetre")
      end
    end
  end
end

exit(Contenus::ExtraireCorrections.run(ARGV)) if $PROGRAM_NAME == __FILE__
