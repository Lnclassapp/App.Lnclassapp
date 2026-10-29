# 🧠 DOMAINE · UseCases::Catalog::ImportCourseTree
# Rôle : adaptateur d'import des leçons v3 (figures, notions à fiche, exercices, questions), tout en brouillon ; réimport d'un brouillon seulement
# ADR  : 0035, 0039, 0105, 0113, 0115, XXXX · UDR : 0038
module UseCases
  module Catalog
    class ImportCourseTree
      include UseCases::Catalog::Importer

      KIND = "course_tree"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::Catalog::ManageContentPolicy
      PUBLIC_ID_LENGTH = 14
      # Clé canonique → clés acceptées, la première présente l'emporte (ADR-0039). Plus lu ici (format 3 : title seul) ;
      # ImportEssentials et la vue de son aide s'en servent encore (jusqu'au Lot R).
      EXERCISE_ALIASES = { "title" => %w[title name] }.freeze
      # ADR-XXXX §4.1 : un exercice par notion, quatre problèmes pour toute la leçon.
      LESSON_EXERCISES = 4
      DEFAULT_THEME = "blue"
      # Lignes écrites par ContentTreeWriter → clé du détail du rapport (une notion est une ligne de la table des fiches).
      DETAILS = { essentials: "essentials_created", exercises: "exercises_created", questions: "questions_created",
                  answers: "answers_created" }.freeze
      Node = Ports::Catalog::ContentTreeWriterPort

      def initialize(courses:, essentials:, taxonomy:, writer:)
        @courses = courses
        @essentials = essentials
        @taxonomy = taxonomy
        @writer = writer
      end

      # Une leçon n'a pas de parent : l'enveloppe ne cite aucune cible.
      def resolve_target(document:) = Shared::Result.success(nil)

      # Les slugs pris sont complétés au fil de la validation : deux leçons du fichier n'en partagent jamais un.
      def prepare(target:)
        Entities::Catalog::ImportContext.new(target:, existing_keys: @courses.existing_keys,
                                             data: { lookup: @taxonomy.lookup, course_ids: @courses.ids_by_key, course_slugs: @courses.taken_slugs,
                                                     essential_slugs: @essentials.taken_slugs })
      end

      def validate_root(root:, path:, context:)
        return Entities::Catalog::ImportItem.new(path:, errors: [ rule_error(path, "schema") ]) unless root.is_a?(Hash)

        lookup = context.data.fetch(:lookup)
        errors = lesson_errors(root, path, lookup)
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        key = course_key(root, lookup)
        existing_id = context.data.fetch(:course_ids)[key]
        return replacement_item(root, path, lookup, key, existing_id) if existing_id

        Entities::Catalog::ImportItem.new(path:, plan: course_node(root, lookup, context.data), key:)
      end

      # Tout le lot dans la transaction du moteur. Les leçons neuves s'écrivent en masse ; chaque brouillon réimporté est remplacé
      # entier (la leçon verrouillée, ses contenus relus sous verrou : ADR-XXXX §4.4).
      def write(items:, author_id:, at:)
        fresh, replaced = items.map(&:plan).partition { it.existing_id.nil? }
        created = @writer.write(courses: fresh, author_id:, at:)
        details = DETAILS.to_h { |rows, detail| [ detail, created.fetch(rows) ] }
        replaced.each do |node|
          counts = @writer.replace_draft(course_id: node.existing_id, tree: node)
          DETAILS.each { |rows, detail| details[detail] += counts.fetch(rows) }
        end
        { imported: items.size, details: }
      end

      private

      # Clé de doublon de la leçon (celle de CourseRepository#existing_keys).
      def course_key(course, lookup)
        [ Entities::Shared::NaturalKey.compact(course["name"].squish), lookup.resolve_level(course["level_name"]).id,
          lookup.resolve_material(course["material_name"]).id, series_id(course["series_name"], lookup) ]
      end

      # ADR-XXXX §4.4 : une leçon déjà en base est remplacée si elle et tout son contenu sont encore en brouillon, refusée sinon.
      # La clé n'est pas celle d'existing_keys : le moteur ne l'ignore pas comme un doublon.
      def replacement_item(course, path, lookup, key, existing_id)
        unless replaceable?(@courses.status_for_update(id: existing_id))
          return Entities::Catalog::ImportItem.new(path:, errors: [ rule_error(path, "lesson_already_published", course: course["name"].squish) ])
        end

        # Ni le slug de la leçon ni ceux des notions ne sont tirés ici : l'écrivain garde le premier et choisit les seconds.
        node = course_node(course, lookup, { course_slugs: Set.new, essential_slugs: Set.new }, existing_id:)
        Entities::Catalog::ImportItem.new(path:, plan: node, key: [ :replace, *key ])
      end

      def replaceable?(status) = status && status.fetch(:course) == "draft" && status.fetch(:contents).all?("draft")

      def lesson_errors(course, path, lookup)
        figures = course["figures"]
        keys = Array(figures).filter_map { it["key"] if it.is_a?(Hash) }.to_set
        notions = Array(course["notions"])
        Entities::Catalog::ContentNode.validate_lesson(course, path:, lookup:) +
          Entities::Catalog::ContentNode.validate_figures(figures, path) +
          notions.each_with_index.flat_map { |notion, index| notion_errors(notion, "#{path}.notions[#{index}]", keys) } +
          repeated_notions(notions, path) + problem_errors(course, path, keys)
      end

      def notion_errors(notion, path, figure_keys)
        errors = Entities::Catalog::ContentNode.validate_notion(notion, path:)
        return errors unless notion.is_a?(Hash)

        errors += Entities::Catalog::ContentNode.validate_figure_citation(notion["figure"], figure_keys, "#{path}.figure")
        exercise = notion["exercise"]
        return errors << rule_error("#{path}.exercise", "schema") unless exercise.is_a?(Hash)

        errors + exercise_errors(exercise, "#{path}.exercise", figure_keys)
      end

      # Quatre problèmes pour toute la leçon, chacun avec son sujet. La leçon est refusée entière.
      def problem_errors(course, path, figure_keys)
        problems = Array(course["exercises"])
        counted = problems.size == LESSON_EXERCISES ? [] : [ rule_error("#{path}.exercises", "lesson_exercise_count", course: course["name"].to_s.squish, count: problems.size, expected: LESSON_EXERCISES) ]
        counted + problems.each_with_index.flat_map { |exercise, rank| exercise_errors(exercise, "#{path}.exercises[#{rank}]", figure_keys) }
      end

      def exercise_errors(exercise, path, figure_keys)
        return [ rule_error(path, "schema") ] unless exercise.is_a?(Hash)

        Entities::Catalog::ContentNode.validate_exercise_v3(exercise, path:) + statement_errors(exercise, path) +
          Entities::Catalog::ContentNode.validate_figure_citation(exercise["figure"], figure_keys, "#{path}.figure")
      end

      def statement_errors(exercise, path)
        exercise["statement"].to_s.squish.empty? ? [ rule_error("#{path}.statement", "blank") ] : []
      end

      def rule_error(path, code, **params) = Entities::Catalog::ImportError.new(path:, code:, params:)

      # L'index unique (leçon, nom) refuserait la seconde notion : l'erreur est notée à son chemin, pas à l'écriture.
      def repeated_notions(notions, path)
        seen = Set.new
        notions.each_with_index.filter_map do |notion, index|
          next unless notion.is_a?(Hash)

          name = Entities::Shared::NaturalKey.normalize(notion["name"])
          next if name.empty? || seen.add?(name)

          rule_error("#{path}.notions[#{index}].name", "invalid_value", value: notion["name"])
        end
      end

      # existing_id : la leçon réimportée, dont le slug est gardé ; ses notions sont écrites avec le slug de base, que l'écrivain rend unique.
      def course_node(course, lookup, data, existing_id: nil)
        name = course["name"].squish
        Node::CourseNode.new(
          slug: (slug_for(name, "course", data.fetch(:course_slugs)) unless existing_id), name:, subtitle: optional(course["subtitle"]),
          content: nil, level_id: lookup.resolve_level(course["level_name"]).id, series_id: series_id(course["series_name"], lookup),
          material_id: lookup.resolve_material(course["material_name"]).id, essentials: [],
          exercises: Array(course["exercises"]).map { exercise_node(it) }, existing_id:,
          figures: Array(course["figures"]).map { figure_hash(it) }, sheet_theme: course["theme"].presence || DEFAULT_THEME,
          notions: Array(course["notions"]).each_with_index.map { |notion, index| notion_node(notion, name, index, data) }
        )
      end

      def figure_hash(raw)
        figure = Entities::Catalog::Figure.from_raw(raw)
        { "key" => figure.key, "kind" => figure.kind, "description" => figure.description.to_s.squish, "params" => figure.params,
          "controls" => figure.controls }
      end

      # Même slug que l'ORM : tiré du nom de la leçon puis de celui de la notion.
      def notion_node(notion, course_name, index, data)
        sheet = Entities::Catalog::NotionSheet.from_raw(notion)
        Node::NotionNode.new(
          slug: slug_for("#{course_name} #{notion['name'].squish}", "essential", data.fetch(:essential_slugs)), course_id: nil,
          name: notion["name"].squish, position: index + 1,
          sheet: { "remember" => sheet.remember, "method" => sheet.method_steps,
                   "example" => { "statement" => sheet.example_statement, "steps" => sheet.example_steps },
                   "pitfall" => sheet.pitfall, "figure_key" => sheet.figure_key },
          exercises: [ exercise_node(notion["exercise"]) ]
        )
      end

      def exercise_node(exercise)
        Node::ExerciseNode.new(
          public_id: SecureRandom.base58(PUBLIC_ID_LENGTH), essential_id: nil, title: exercise["title"].squish,
          statement: exercise["statement"].to_s.strip, exercise_type: exercise["exercise_type"], position: nil,
          statement_blocks: exercise["statement_blocks"].presence, figure_key: exercise["figure"].presence,
          questions: exercise["questions"].each_with_index.map { |question, rank| Node::QuestionNode.from_import(question, position: rank + 1) }
        )
      end

      # Une série est facultative : ContentNode a déjà refusé une série donnée mais inconnue.
      def series_id(name, lookup)
        series = lookup.resolve_series(name)
        return if series.nil?

        series.id
      end

      # Un nom sans lettre latine (« π ») donne un slug vide : le nom du modèle le remplace, comme dans l'ORM.
      def slug_for(source, fallback, taken)
        Entities::Catalog::Slug.unique(source.parameterize.presence || fallback, taken:)
      end

      def optional(value) = value.to_s.squish.presence
    end
  end
end
