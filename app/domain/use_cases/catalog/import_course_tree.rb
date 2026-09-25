# 🧠 DOMAINE · UseCases::Catalog::ImportCourseTree
# Rôle : adaptateur d'import des cours complets (fiches, exercices, questions, propositions), tout en draft
# ADR  : 0035, 0039 · UDR : 0038
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
      EXERCISE_ALIASES = { "title" => %w[title name] }.freeze
      # Lignes écrites par ContentTreeWriter → clé du détail du rapport.
      DETAILS = { essentials: "essentials_created", exercises: "exercises_created", questions: "questions_created",
                  answers: "answers_created" }.freeze
      Node = Ports::Catalog::ContentTreeWriterPort

      def initialize(courses:, essentials:, taxonomy:, writer:)
        @courses = courses
        @essentials = essentials
        @taxonomy = taxonomy
        @writer = writer
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
        course = canonical(root)
        lookup = context.data.fetch(:lookup)
        errors = Entities::Catalog::ContentNode.validate_course(course, path:, lookup:) + repeated_essentials(course, path)
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        node = course_node(course, lookup, context.data)
        Entities::Catalog::ImportItem.new(path:, plan: node,
                                          key: [ Entities::Shared::NaturalKey.compact(node.name), node.level_id, node.material_id, node.series_id ])
      end

      # Tout le lot dans la transaction du moteur ; le contenu HTML est assaini par l'écrivain.
      def write(items:, author_id:, at:)
        created = @writer.write(courses: items.map(&:plan), author_id:, at:)
        { imported: items.size, details: DETAILS.to_h { |rows, detail| [ detail, created.fetch(rows) ] } }
      end

      private

      # Les alias de l'ancienne application ramenés aux clés que ContentNode lit ; la clé status est ignorée.
      def canonical(course)
        essentials = Array(course["essentials"]).map do |essential|
          essential.merge("exercises" => Array(essential["exercises"]).map { |exercise| exercise.merge(aliased(exercise, EXERCISE_ALIASES)) })
        end
        course.merge(aliased(course, COURSE_ALIASES), "essentials" => essentials)
      end

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
          essentials: course["essentials"].each_with_index.map { |essential, index| essential_node(essential, name, index, data) }
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
          description: exercise["description"].to_s.strip.presence, exercise_type: exercise["exercise_type"], position: index + 1,
          questions: exercise["questions"].each_with_index.map { |question, rank| question_node(question, rank) }
        )
      end

      # L'ancienne application nomme is_correct ce que le schéma nomme correct.
      def question_node(question, index)
        answers = question["answers"].each_with_index.map do |answer, rank|
          Node::AnswerNode.new(position: rank + 1, content: answer["content"].strip,
                               correct: answer.fetch("correct") { answer["is_correct"] } == true)
        end
        Node::QuestionNode.new(position: index + 1, content: question["content"].strip, explanation: question["explanation"].to_s.strip.presence,
                               question_type: question["question_type"], answers:)
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
