# 🧠 DOMAINE · UseCases::Catalog::ImportEssentials
# Rôle : adaptateur d'import des fiches essentielles d'un cours, avec leurs exercices, à la suite des fiches existantes, tout en draft
# ADR  : 0035, 0039 · UDR : 0039
module UseCases
  module Catalog
    class ImportEssentials
      include UseCases::Catalog::Importer

      KIND = "essentials"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::Catalog::ManageContentPolicy
      PUBLIC_ID_LENGTH = 14
      # Lignes écrites par ContentTreeWriter → clé du détail du rapport ; les fiches sont le compteur « Importés ».
      DETAILS = { exercises: "exercises_created", questions: "questions_created", answers: "answers_created" }.freeze
      Node = Ports::Catalog::ContentTreeWriterPort

      def initialize(courses:, essentials:, writer:)
        @courses = courses
        @essentials = essentials
        @writer = writer
      end

      # Le slug exact du cours : une fiche n'entre jamais dans un cours que le fichier ne désigne pas.
      def resolve_target(document:)
        course = @courses.find_by_slug(slug: document["course"].to_s.strip)
        return Shared::Result.failure(:not_found) if course.nil?

        Shared::Result.success(course)
      end

      # Les positions partent de next_position et n'avancent qu'à l'écriture : ni doublon, ni lot refusé ne laisse de trou.
      def prepare(target:)
        @next_position = @essentials.next_position(course_id: target.id)
        Entities::Catalog::ImportContext.new(target:, existing_keys: @essentials.existing_keys(course_ids: [ target.id ]),
                                             data: { slugs: @essentials.taken_slugs })
      end

      def validate_root(root:, path:, context:)
        essential = canonical(root)
        errors = Entities::Catalog::ContentNode.validate_essential(essential, path:)
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        course = context.target
        Entities::Catalog::ImportItem.new(path:, plan: essential_node(essential, course, context.data.fetch(:slugs)),
                                          key: [ course.id, Entities::Shared::NaturalKey.normalize(essential["name"]) ])
      end

      # Tout le lot dans la transaction du moteur ; le contenu HTML est assaini par l'écrivain.
      def write(items:, author_id:, at:)
        essentials = items.each_with_index.map { |item, index| item.plan.with(position: @next_position + index) }
        created = @writer.write(essentials:, author_id:, at:)
        @next_position += items.size
        { imported: items.size, details: DETAILS.to_h { |rows, detail| [ detail, created.fetch(rows) ] } }
      end

      private

      # Un exercice garde les clés de l'ancienne application, comme dans l'import des cours complets ; status est ignorée.
      def canonical(essential)
        exercises = Array(essential["exercises"]).map do |exercise|
          exercise.merge(ImportCourseTree::EXERCISE_ALIASES.transform_values { |keys| exercise[keys.find { exercise.key?(it) }] })
        end
        essential.merge("exercises" => exercises)
      end

      # Même slug que l'ORM : tiré du nom du cours puis de celui de la fiche ; sans lettre latine, le nom du modèle.
      def essential_node(essential, course, slugs)
        name = essential["name"].squish
        Node::EssentialNode.new(
          slug: Entities::Catalog::Slug.unique("#{course.name} #{name}".parameterize.presence || "essential", taken: slugs),
          course_id: course.id, name:, subtitle: essential["subtitle"].to_s.squish.presence, content: essential["content"],
          position: nil, exercises: essential["exercises"].each_with_index.map { |exercise, rank| exercise_node(exercise, rank) }
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
    end
  end
end
