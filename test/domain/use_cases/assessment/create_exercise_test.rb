require "test_helper"

module UseCases
  module Assessment
    class CreateExerciseTest < ActiveSupport::TestCase
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")

      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        def initialize(essential)
          @essential = essential
        end

        def find_by_slug(slug:)
          @essential if slug == @essential.slug
        end
      end

      # Comme le repository : l'exercice, ses questions et ses propositions en une écriture ; refuse lève comme la base.
      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        attr_reader :created

        def initialize(refuse: false)
          @refuse = refuse
        end

        def create(exercise:)
          raise FakeTransaction::Refused if @refuse

          exercise.id = 40
          exercise.public_id = "ExErCiCe000040"
          @created = exercise
        end
      end

      setup do
        @essential = Entities::Catalog::Essential.new(id: 9, slug: "la-meiose", name: "La méiose", course_id: 3, status: "draft")
        @exercises = FakeExercises.new
        @transaction = FakeTransaction.new
      end

      def question(content, question_type, *answers)
        { content:, question_type:, explanation: "Parce que.",
          answers_attributes: answers.each_with_index.to_h { |(text, correct), index| [ index.to_s, { content: text, correct: correct ? "1" : "0" } ] } }
      end

      # Une question de chacun des quatre types, toutes bien construites.
      def four_types
        { "0" => question("La méiose produit 4 cellules.", "true_false", [ "Vrai", true ], [ "Faux", false ]),
          "1" => question("Combien de chromosomes ?", "single_choice", [ "23", true ], [ "46", false ], [ "92", false ]),
          "2" => question("Deux phases ?", "multiple_correct_2", [ "Méiose I", true ], [ "Méiose II", true ], [ "Mitose", false ]),
          "3" => question("Trois vrais ?", "multiple_correct_3", [ "A", true ], [ "B", true ], [ "C", true ], [ "D", false ]) }
      end

      def create(questions: four_types, title: "méiose et ADN", actor: TEAM, slug: "la-meiose", exercises: @exercises)
        dto = Dtos::Assessment::ExerciseInput.from_params({ title:, description: "Consigne", exercise_type: "evaluation",
                                                            questions_attributes: questions }.with_indifferent_access)
        CreateExercise.new(exercises:, essentials: FakeEssentials.new(@essential), transaction: @transaction,
                           policy: Policies::Catalog::ManageContentPolicy.new)
                      .call(actor:, essential_slug: slug, dto:)
      end

      test "crée en brouillon, en une transaction, l'exercice et ses questions des quatre types, titre sans changement de casse" do
        result = create

        assert result.success?
        exercise = result.value
        assert_same @exercises.created, exercise
        assert_equal [ "méiose et ADN", "Consigne", "evaluation", "draft", 9, 7 ],
                     [ exercise.title, exercise.description, exercise.exercise_type, exercise.status, exercise.essential_id, exercise.author_id ]
        assert_equal %w[true_false single_choice multiple_correct_2 multiple_correct_3], exercise.questions.map(&:question_type)
        assert_equal [ 1, 2, 3, 4 ], exercise.questions.map(&:position)
        assert_equal [ 2, 3, 3, 4 ], exercise.questions.map { it.answers.size }
        assert_equal [ 1, 1, 2, 3 ], exercise.questions.map { it.correct_answer_ids.size }
        assert_equal 1, @transaction.attempts
      end

      test "un exercice peut naître sans question : il ne sera publiable qu'avec au moins une" do
        result = create(questions: {})

        assert result.success?
        assert_empty result.value.questions
      end

      test "hors équipe, rien n'est écrit, même pour une fiche essentielle inconnue" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, create(actor: teacher).code
        assert_equal :forbidden, create(actor: nil, slug: "inconnue").code
        assert_nil @exercises.created
      end

      test "une fiche essentielle inconnue est introuvable" do
        assert_equal :not_found, create(slug: "inconnue").code
        assert_equal 0, @transaction.attempts
      end

      test "une saisie incomplète est refusée sans rien écrire" do
        result = create(title: "", questions: { "0" => question("", "single_choice", [ "A", true ], [ "B", false ]) })

        assert_equal :invalid, result.code
        assert_equal %i[title questions], result.errors.keys
        assert_nil @exercises.created
      end

      test "un titre trop long est refusé par l'entité" do
        result = create(title: "a" * (Entities::Assessment::Exercise::TITLE_MAX + 1))

        assert_equal [ :invalid, [ :title ] ], [ result.code, result.errors.keys ]
        assert_nil @exercises.created
      end

      test "chaque type a sa structure : une question mal construite est signalée à sa place, et rien n'est écrit" do
        result = create(questions: {
          "0" => question("Vrai/Faux à 3", "true_false", [ "Vrai", true ], [ "Faux", false ], [ "Peut-être", false ]),
          "1" => question("Choix unique à 2 correctes", "single_choice", [ "A", true ], [ "B", true ]),
          "2" => question("Bien construite", "single_choice", [ "A", true ], [ "B", false ]),
          "3" => question("Une seule proposition", "multiple_correct_2", [ "A", true ]),
          "4" => question("3 correctes, 2 cochées", "multiple_correct_3", [ "A", true ], [ "B", true ], [ "C", false ], [ "D", false ]),
          "5" => question("Aucune correcte", "single_choice", [ "A", false ], [ "B", false ])
        })

        assert_equal :invalid, result.code
        assert_equal({ "questions[0]": [ :true_false_needs_two_answers ], "questions[1]": [ :wrong_correct_count ],
                       "questions[3]": %i[too_few_answers wrong_correct_count], "questions[4]": [ :wrong_correct_count ],
                       "questions[5]": [ :wrong_correct_count ] }, result.errors)
        assert_nil @exercises.created
        assert_equal 0, @transaction.attempts
      end

      test "une écriture refusée par la base est un conflit, sans exception" do
        result = create(exercises: FakeExercises.new(refuse: true))

        assert_equal [ :conflict, { base: [ :write_failed ] } ], [ result.code, result.errors ]
      end
    end
  end
end
