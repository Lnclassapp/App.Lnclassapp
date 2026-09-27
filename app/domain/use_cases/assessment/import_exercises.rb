# 🧠 DOMAINE · UseCases::Assessment::ImportExercises
# Rôle : adaptateur d'import des exercices d'une fiche essentielle (questions et propositions comprises), tout en draft
# ADR  : 0035, 0039 · UDR : 0040
module UseCases
  module Assessment
    class ImportExercises
      include UseCases::Catalog::Importer

      KIND = "exercises"
      # Le moteur autorise l'auteur par le registre des types (ImportKind) ; c'est la même policy.
      POLICY = Policies::Catalog::ManageContentPolicy
      PUBLIC_ID_LENGTH = 14
      # Clé canonique → clés acceptées, la première présente l'emporte (ADR-0039), comme dans l'arbre de cours (I1).
      ALIASES = { "title" => %w[title name] }.freeze
      # Lignes écrites par ContentTreeWriter → clé du détail du rapport ; le nombre d'exercices est le compteur « Importés ».
      DETAILS = { questions: "questions_created", answers: "answers_created" }.freeze
      Node = Ports::Catalog::ContentTreeWriterPort

      def initialize(essentials:, exercises:, writer:)
        @essentials = essentials
        @exercises = exercises
        @writer = writer
      end

      # La fiche cible de l'enveloppe, par son slug, quel que soit son statut : tout ce qui y entre naît draft.
      def resolve_target(document:)
        essential = @essentials.find_by_slug(slug: document["essential"].to_s.parameterize)
        return Shared::Result.failure(:not_found) if essential.nil?

        Shared::Result.success(essential)
      end

      # Seuls les exercices de la fiche cible peuvent être des doublons.
      def prepare(target:)
        Entities::Catalog::ImportContext.new(target:, existing_keys: @exercises.existing_keys(essential_ids: [ target.id ]))
      end

      def validate_root(root:, path:, context:)
        exercise = root.merge(ALIASES.transform_values { |keys| root[keys.find { root.key?(it) }] })
        errors = Entities::Catalog::ContentNode.validate_exercise(exercise, path:)
        return Entities::Catalog::ImportItem.new(path:, errors:) if errors.any?

        node = exercise_node(exercise, context.target.id)
        Entities::Catalog::ImportItem.new(path:, plan: node, key: [ node.essential_id, Entities::Shared::NaturalKey.normalize(node.title) ])
      end

      # Positions lues au moment d'écrire : à la suite de la fiche, sans trou pour les éléments écartés ni pour un lot rejoué.
      def write(items:, author_id:, at:)
        essential_id = items.first.plan.essential_id
        first = @exercises.next_positions(essential_ids: [ essential_id ]).fetch(essential_id)
        nodes = items.each_with_index.map { |item, index| item.plan.with(position: first + index) }
        created = @writer.write(exercises: nodes, author_id:, at:)
        { imported: items.size, details: DETAILS.to_h { |rows, detail| [ detail, created.fetch(rows) ] } }
      end

      private

      # La clé status est ignorée ; la position est posée à l'écriture.
      def exercise_node(exercise, essential_id)
        Node::ExerciseNode.new(
          public_id: SecureRandom.base58(PUBLIC_ID_LENGTH), essential_id:, title: exercise["title"].squish,
          description: exercise["description"].to_s.strip.presence, exercise_type: exercise["exercise_type"], position: nil,
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
