# 🧠 DOMAINE · UseCases::Catalog::ImportCourseTree
# Rôle : adaptateur d'import des cours complets (notions, exercices, questions, propositions), tout en draft ; format 2 lu, format 1 toléré
# ADR  : 0035, 0039, 0105, 0113 · UDR : 0038
module UseCases
  module Catalog
    class ImportCourseTree
      include UseCases::Catalog::Importer

      KIND = "course_tree"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::Catalog::ManageContentPolicy
      PUBLIC_ID_LENGTH = 14
      # Clé canonique → clés acceptées, la première présente l'emporte (ADR-0039).
      COURSE_ALIASES = { "name" => %w[name nom], "subtitle" => %w[subtitle sous_titre] }.freeze
      # Plus lu ici (format 2 : title seul) ; ImportEssentials, qui lit encore les exercices de l'ancien format, s'en sert.
      EXERCISE_ALIASES = { "title" => %w[title name] }.freeze
      # ADR-0113 §4.4 : un exercice par notion, quatre exercices de toute la leçon.
      LESSON_EXERCISES = 4
      # Le format 1 ne porte plus d'exercices : ils sont ignorés et comptés dans le rapport (clé du détail).
      IGNORED_DETAIL = "exercises_ignored_v1"
      # Lignes écrites par ContentTreeWriter → clé du détail du rapport.
      DETAILS = { essentials: "essentials_created", exercises: "exercises_created", questions: "questions_created",
                  answers: "answers_created" }.freeze
      Node = Ports::Catalog::ContentTreeWriterPort

      def initialize(courses:, essentials:, taxonomy:, writer:)
        @courses = courses
        @essentials = essentials
        @taxonomy = taxonomy
        @writer = writer
        # Exercices du format 1 ignorés, par slug de leçon : validate_root les compte, write les annonce au rapport.
        @ignored_exercises = {}
      end

      # Un cours n'a pas de parent : l'enveloppe ne cite aucune cible.
      def resolve_target(document:) = Shared::Result.success(nil)

      # Les slugs pris sont complétés au fil de la validation : deux cours du fichier n'en partagent jamais un.
      def prepare(target:)
        Entities::Catalog::ImportContext.new(target:, existing_keys: @courses.existing_keys,
                                             data: { lookup: @taxonomy.lookup, course_slugs: @courses.taken_slugs,
                                                     essential_slugs: @essentials.taken_slugs })
      end

      def validate_root(root:, path:, context:)
        legacy = context.data.fetch(:version, Entities::Catalog::ImportKind::COURSE_TREE_VERSION) != Entities::Catalog::ImportKind::COURSE_TREE_VERSION
        course = canonical(root)
        ignored = legacy ? ignore_exercises(course) : 0
        lookup = context.data.fetch(:lookup)
        errors = Entities::Catalog::ContentNode.validate_course(course, path:, lookup:) + repeated_essentials(course, path)
        errors += exercise_errors(course, path) unless legacy
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        node = course_node(course, lookup, context.data)
        @ignored_exercises[node.slug] = ignored
        Entities::Catalog::ImportItem.new(path:, plan: node,
                                          key: [ Entities::Shared::NaturalKey.compact(node.name), node.level_id, node.material_id, node.series_id ])
      end

      # Tout le lot dans la transaction du moteur ; le contenu HTML est assaini par l'écrivain.
      def write(items:, author_id:, at:)
        created = @writer.write(courses: items.map(&:plan), author_id:, at:)
        details = DETAILS.to_h { |rows, detail| [ detail, created.fetch(rows) ] }
        ignored = items.sum { @ignored_exercises.fetch(it.plan.slug) }
        details[IGNORED_DETAIL] = ignored if ignored.positive?
        { imported: items.size, details: }
      end

      private

      # Les alias de l'ancienne application ramenés aux clés que ContentNode lit ; la clé status est ignorée.
      def canonical(course)
        essentials = Array(course["essentials"]).map { |essential| essential.merge("exercises" => Array(essential["exercises"])) }
        course.merge(aliased(course, COURSE_ALIASES), "essentials" => essentials)
      end

      # Format 1 : les exercices des notions ne sont ni lus ni validés (ADR-0113 §4.4). → leur nombre
      def ignore_exercises(course)
        course["essentials"].sum { |essential| essential.fetch("exercises").size.tap { essential["exercises"] = [] } }
      end

      # Format 2, ADR-0113 §4.4 : un exercice par notion, quatre pour toute la leçon, chacun avec son sujet. La leçon est refusée entière.
      def exercise_errors(course, path)
        name = course["name"].to_s.squish
        per_essential = course["essentials"].each_with_index.flat_map do |essential, index|
          count = essential["exercises"].size
          errors = count == 1 ? [] : [ rule_error("#{path}.essentials[#{index}].exercises", "essential_exercise_count", course: name, name: essential["name"].to_s.squish, count:) ]
          errors + essential["exercises"].each_with_index.flat_map { |exercise, rank| statement_errors(exercise, "#{path}.essentials[#{index}].exercises[#{rank}]") }
        end
        lesson = Array(course["exercises"])
        counted = lesson.size == LESSON_EXERCISES ? [] : [ rule_error("#{path}.exercises", "lesson_exercise_count", course: name, count: lesson.size, expected: LESSON_EXERCISES) ]
        per_essential + counted + lesson.each_with_index.flat_map { |exercise, rank| lesson_exercise_errors(exercise, "#{path}.exercises[#{rank}]") }
      end

      def lesson_exercise_errors(exercise, path)
        Entities::Catalog::ContentNode.validate_exercise(exercise, path:) + statement_errors(exercise, path)
      end

      def statement_errors(exercise, path)
        exercise["statement"].to_s.squish.empty? ? [ rule_error("#{path}.statement", "blank") ] : []
      end

      def rule_error(path, code, **params) = Entities::Catalog::ImportError.new(path:, code:, params:)

      def aliased(hash, aliases) = aliases.transform_values { |keys| hash[keys.find { hash.key?(it) }] }

      # L'index unique (cours, nom) refuserait la seconde fiche : l'erreur est notée à son chemin, pas à l'écriture.
      def repeated_essentials(course, path)
        seen = Set.new
        course["essentials"].each_with_index.filter_map do |essential, index|
          name = Entities::Shared::NaturalKey.normalize(essential["name"])
          next if name.empty? || seen.add?(name)

          Entities::Catalog::ImportError.new(path: "#{path}.essentials[#{index}].name", code: "invalid_value",
                                             params: { value: essential["name"] })
        end
      end

      def course_node(course, lookup, data)
        name = course["name"].squish
        Node::CourseNode.new(
          slug: slug_for(name, "course", data.fetch(:course_slugs)), name:, subtitle: optional(course["subtitle"]),
          content: course["content"], level_id: lookup.resolve_level(course["level_name"]).id,
          series_id: series_id(course["series_name"], lookup), material_id: lookup.resolve_material(course["material_name"]).id,
          essentials: course["essentials"].each_with_index.map { |essential, index| essential_node(essential, name, index, data) },
          exercises: Array(course["exercises"]).each_with_index.map { |exercise, rank| exercise_node(exercise, rank) }
        )
      end

      # Même slug que l'ORM : tiré du nom du cours puis de celui de la fiche.
      def essential_node(essential, course_name, index, data)
        name = essential["name"].squish
        Node::EssentialNode.new(
          slug: slug_for("#{course_name} #{name}", "essential", data.fetch(:essential_slugs)), course_id: nil, name:,
          subtitle: optional(essential["subtitle"]), content: essential["content"], position: index + 1,
          exercises: essential["exercises"].each_with_index.map { |exercise, rank| exercise_node(exercise, rank) }
        )
      end

      def exercise_node(exercise, index)
        Node::ExerciseNode.new(
          public_id: SecureRandom.base58(PUBLIC_ID_LENGTH), essential_id: nil, title: exercise["title"].squish,
          statement: exercise["statement"].to_s.strip, exercise_type: exercise["exercise_type"], position: index + 1,
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
