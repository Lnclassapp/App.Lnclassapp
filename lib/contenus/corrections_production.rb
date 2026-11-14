# frozen_string_literal: true

# Reporte en production les corrections du validateur pédagogique (docs/chantiers/corrections-production/corrections.json) en passant
# par les use cases « Modifier le texte » (CorrectNotionText, CorrectExerciseText) : journal content.corrected, anciens scores gardés.
# Une correction n'est écrite que si la valeur en base est exactement l'« Avant » ; sinon elle est listée, jamais forcée.
# Lancé par `bin/rails contenus:corriger` (essai par défaut ; --appliquer écrit). Chantier corrections-production, à retirer une fois appliqué.
module Contenus
  class CorrectionsProduction
    Row = Data.define(:file, :place, :field, :status, :detail)
    STATUSES = %i[a_appliquer deja_a_jour introuvable hors_perimetre appliquee echec].freeze

    def initialize(data:, actor:, notion_use_case:, exercise_use_case:, out: $stdout)
      @data = data
      @actor = actor
      @notion_use_case = notion_use_case
      @exercise_use_case = exercise_use_case
      @out = out
    end

    # → [Row]
    def call(apply: false)
      rows = @data.fetch("lessons").flat_map { lesson(it, apply:) }
      report(rows, apply:)
      rows
    end

    private

    def lesson(lesson, apply:)
      course = find_course(lesson.fetch("course"))
      changes = lesson.fetch("changes")
      file = lesson.fetch("file")
      return changes.map { row(file, it, :introuvable, "leçon absente de la base") } if course.nil?

      outside, inside = changes.partition { it["kind"] == "hors_perimetre" }
      rows = outside.map { row(file, it, :hors_perimetre, "aucun use case ne l'écrit : à reporter à la main") }
      rows + notion_rows(course, file, inside.select { it["kind"] == "notion" }, apply:) +
        exercise_rows(course, file, inside.select { it["kind"] == "exercise" }, apply:)
    end

    def find_course(identity)
      scope = Orm::Course.joins(:level, :material).where(name: identity["name"], levels: { name: identity["level_name"] },
                                                         materials: { name: identity["material_name"] })
      scope = identity["series_name"] ? scope.joins(:series).where(series: { name: identity["series_name"] }) : scope.where(series_id: nil)
      scope.first
    end

    # --- Notions -------------------------------------------------------------------------------------------------------------

    def notion_rows(course, file, changes, apply:)
      essentials = course.essentials.where(archived_at: nil).order(:position).to_a
      changes.group_by { it["notion"] }.flat_map do |index, group|
        record = essentials[index]
        next group.map { row(file, it, :introuvable, "notion absente") } if record.nil?

        doc = record.sheet.deep_dup.merge("name" => record.name)
        group.map { |change| [ change, notion_status(change, doc) ] }.then { settle_notion(file, record, doc, it, apply:) }
      end
    end

    # « example.steps[2] » → ["example", "steps", 2] : le nom et les blocs de la fiche se lisent et s'écrivent par le même chemin.
    def keys_of(field) = field.split(/\.|\[(\d+)\]/).reject(&:empty?).map { it.match?(/\A\d+\z/) ? it.to_i : it }

    def notion_status(change, doc)
      keys = keys_of(change["field"])
      current = doc.dig(*keys)
      return :deja_a_jour if same?(current, change["apres"])
      return :introuvable unless same?(current, change["avant"])

      keys[0..-2].reduce(doc) { |node, key| node[key] }[keys.last] = change["apres"]
      :a_appliquer
    end

    def settle_notion(file, record, doc, statuses, apply:)
      rows = rows_of(file, statuses)
      return rows unless writable?(apply, statuses)

      text = UseCases::Catalog::CorrectNotionText::NotionText.new(
        name: doc["name"], remember: doc["remember"].to_s, method_steps: Array(doc["method"]).map(&:to_s),
        example_statement: doc.dig("example", "statement").to_s, example_steps: Array(doc.dig("example", "steps")).map(&:to_s),
        pitfall: doc["pitfall"].to_s
      )
      conclude(rows, @notion_use_case.call(actor: @actor, slug: record.slug, text:))
    end

    # --- Exercices -----------------------------------------------------------------------------------------------------------

    def exercise_rows(course, file, changes, apply:)
      changes.group_by { it.slice("group", "notion", "subject", "exercise") }.flat_map do |place, group|
        record = find_exercise(course, place)
        next group.map { row(file, it, :introuvable, "exercice absent") } if record.nil?

        entity = Repositories::Assessment::ExerciseRepository.new.find(id: record.id)
        edit = ExerciseEdit.new(entity)
        statuses = group.map { |change| [ change, edit.stage(change) ] }
        rows = rows_of(file, statuses)
        next rows unless writable?(apply, statuses)

        conclude(rows, @exercise_use_case.call(actor: @actor, public_id: entity.public_id, text: edit.text))
      end
    end

    def find_exercise(course, place)
      scope = Orm::Exercise.where(course_id: course.id).where(archived_at: nil).order(:position, :id)
      scope = case place["group"]
      when "notion"
        notion = course.essentials.where(archived_at: nil).order(:position).to_a[place["notion"]]
        notion && scope.where(essential_id: notion.id)
      when "problem" then scope.where(essential_id: nil, subject_id: nil)
      else
        subject = course.subjects.order(:position).to_a[place["subject"]]
        subject && scope.where(subject_id: subject.id)
      end
      scope&.to_a&.at(place["exercise"])
    end

    # Le texte d'un exercice relu en base, modifié champ par champ ; chaque champ n'est remplacé que s'il vaut l'« Avant ».
    class ExerciseEdit
      def initialize(entity)
        @values = { "title" => entity.title.to_s, "statement" => entity.statement.to_s, "hint" => entity.hint.to_s }
        @questions = entity.questions.sort_by(&:position).map do |question|
          { "id" => question.id, "content" => question.content.to_s, "explanation" => question.explanation.to_s, "hint" => question.hint.to_s,
            "answers" => question.answers.sort_by(&:position).map { { "id" => it.id, "content" => it.content, "match" => it.match_content, "correct" => it.correct } } }
        end
      end

      def stage(change)
        slot, key = locate(change)
        return :introuvable if slot.nil?

        current = slot[key]
        return :deja_a_jour if same?(current, change["apres"])
        return :introuvable unless same?(current, change["avant"])

        slot[key] = change["apres"]
        :a_appliquer
      end

      def text
        use_case = UseCases::Assessment::CorrectExerciseText
        questions = @questions.map do |question|
          answers = question["answers"].map { use_case::AnswerText.new(id: it["id"], content: it["content"], match_content: it["match"], correct: it["correct"]) }
          use_case::QuestionText.new(id: question["id"], content: question["content"], explanation: question["explanation"], hint: question["hint"], answers:)
        end
        use_case::ExerciseText.new(title: @values["title"], statement: @values["statement"], hint: @values["hint"], questions:)
      end

      private

      def same?(current, expected) = Contenus::CorrectionsProduction.same?(current, expected)

      def locate(change)
        field = change["field"]
        return [ @values, field ] unless change.key?("question")

        question = @questions[change["question"]]
        return if question.nil?
        return [ question, field ] unless change.key?("answer")

        answer = question["answers"][change["answer"]]
        answer && [ answer, field ]
      end
    end

    # --- Communs -------------------------------------------------------------------------------------------------------------

    def conclude(rows, result)
      return rows.map { it.status == :a_appliquer ? it.with(status: :appliquee) : it } if result.success?

      rows.map { it.status == :a_appliquer ? it.with(status: :echec, detail: "#{result.code} #{result.errors.to_h.to_json}") : it }
    end

    def writable?(apply, statuses) = apply && statuses.any? { it.last == :a_appliquer } && statuses.none? { it.last == :introuvable }

    # Une cible (notion ou exercice) s'écrit en entier ou pas du tout : un champ introuvable laisse les autres à reporter à la main,
    # sinon le texte écrit se contredirait (ex. une explication qui annonce une réponse que la correction n'a pas pu ajouter).
    def rows_of(file, statuses)
      blocked = statuses.any? { it.last == :introuvable }
      statuses.map do |change, status|
        next row(file, change, :introuvable, "la valeur en base n'est pas l'Avant") if status == :introuvable
        next row(file, change, :introuvable, "un autre champ de la même cible est introuvable : cible laissée telle quelle") if blocked && status == :a_appliquer

        row(file, change, status, nil)
      end
    end

    def row(file, change, status, detail)
      Row.new(file:, place: change["path"], field: change["field"], status:, detail:)
    end

    def same?(current, expected) = self.class.same?(current, expected)

    # Égalité exacte du texte (espaces de bord exceptés), ou du booléen.
    def self.same?(current, expected)
      return current == expected unless current.is_a?(String) && expected.is_a?(String)

      current.strip == expected.strip
    end

    def report(rows, apply:)
      @out.puts "Mode : #{apply ? 'APPLIQUER (écritures)' : 'essai (aucune écriture)'}"
      rows.group_by(&:status).sort_by { |status, _| STATUSES.index(status) }.each { |status, group| @out.puts "#{status} : #{group.size}" }
      rows.reject { %i[deja_a_jour appliquee a_appliquer].include?(it.status) }.each do |row|
        @out.puts "  [#{row.status}] #{row.file} · #{row.place} — #{row.detail}"
      end
    end
  end
end
