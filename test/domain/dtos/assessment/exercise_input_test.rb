require "test_helper"

module Dtos
  module Assessment
    class ExerciseInputTest < ActiveSupport::TestCase
      # Ce que fields_for envoie : des questions indexées, chacune avec ses propositions indexées.
      def params(title: "Méiose", questions: nil)
        questions ||= {
          "0" => { content: "La méiose produit 4 cellules.", explanation: "Deux divisions successives.", question_type: "true_false",
                   answers_attributes: { "0" => { content: "Vrai", correct: "1" }, "1" => { content: "Faux", correct: "0" } } },
          "1727000000000" => { content: "Combien de chromosomes ?", question_type: "single_choice",
                               answers_attributes: { "0" => { content: "23", correct: "1" }, "1" => { content: "46", correct: "0" },
                                                     "2" => { content: "92", correct: "0" } } }
        }
        ActionController::Parameters.new(title:, description: "  Consigne  ", exercise_type: "fixation",
                                         questions_attributes: questions).permit!.to_h
      end

      test "from_params construit l'arbre des questions et des propositions, dans l'ordre du formulaire" do
        input = ExerciseInput.from_params(params)

        assert input.valid?
        assert_equal [ "Méiose", "Consigne", "fixation" ], [ input.title, input.description, input.exercise_type ]
        assert_equal [ "true_false", "single_choice" ], input.questions.map(&:question_type)
        assert_equal "Deux divisions successives.", input.questions.first.explanation
        assert_nil input.questions.last.explanation
        assert_equal [ [ "Vrai", true ], [ "Faux", false ] ], input.questions.first.answers.map { [ it.content, it.correct ] }
        assert_equal 3, input.questions.last.answers.size
      end

      test "sans question envoyée, l'exercice n'a aucune question ; un tableau est lu comme des champs indexés" do
        assert_empty ExerciseInput.from_params(params.except("questions_attributes")).questions

        listed = ExerciseInput.from_params(params(questions: [ { content: "Q", question_type: "single_choice" } ]))
        assert_equal [ "Q" ], listed.questions.map(&:content)
        assert_empty listed.questions.first.answers
      end

      test "le titre garde sa casse ; ses espaces en trop sont retirés" do
        assert_equal "méiose et ADN", ExerciseInput.from_params(params(title: "  méiose   et ADN ")).title
      end

      test "titre et type sont obligatoires ; la longueur du titre est une règle de l'entité" do
        input = ExerciseInput.new(title: " ", exercise_type: "quiz")

        assert_not input.valid?
        assert input.errors.of_kind?(:title, :blank)
        assert input.errors.of_kind?(:exercise_type, :inclusion)
        assert ExerciseInput.new(title: "a" * 300, exercise_type: "evaluation").valid?
      end

      test "une question ou une proposition incomplète rend l'exercice invalide, l'erreur restant sur son champ" do
        input = ExerciseInput.from_params(params(questions: {
          "0" => { content: "", question_type: "inconnu", answers_attributes: { "0" => { content: " ", correct: "1" } } },
          "1" => { content: "Bonne question", question_type: "single_choice",
                   answers_attributes: { "0" => { content: "a" * 501, correct: "0" }, "1" => { content: "B", correct: "1" } } }
        }))

        assert_not input.valid?
        assert input.errors.of_kind?(:questions, :invalid)
        first, second = input.questions
        assert first.errors.of_kind?(:content, :blank)
        assert first.errors.of_kind?(:question_type, :inclusion)
        assert first.errors.of_kind?(:answers, :invalid)
        assert first.answers.first.errors.of_kind?(:content, :blank)
        assert second.errors.of_kind?(:answers, :invalid)
        assert second.answers.first.errors.of_kind?(:content, :too_long)
        assert_empty second.answers.last.errors
      end

      test "chaque question devient une entité Question à sa position, ses propositions aussi" do
        questions = ExerciseInput.from_params(params).question_entities

        assert_equal [ 1, 2 ], questions.map(&:position)
        assert_equal [ nil, nil ], questions.map(&:id)
        assert_equal [ [ 1, "Vrai", true ], [ 2, "Faux", false ] ], questions.first.answers.map { [ it.position, it.content, it.correct ] }
        assert_empty questions.first.structure_errors
      end

      test "from_exercise remplit le formulaire d'édition depuis l'exercice enregistré" do
        answer = Entities::Assessment::Answer.new(id: 5, position: 1, content: "Vrai", correct: true)
        question = Entities::Assessment::Question.new(id: 4, position: 1, content: "Q", explanation: "E", question_type: "true_false",
                                                      answers: [ answer ])
        exercise = Entities::Assessment::Exercise.new(title: "Méiose", description: "D", exercise_type: "evaluation",
                                                      questions: [ question ])

        input = ExerciseInput.from_exercise(exercise)

        assert_equal [ "Méiose", "D", "evaluation" ], [ input.title, input.description, input.exercise_type ]
        assert_equal [ [ "Q", "E", "true_false" ] ], input.questions.map { [ it.content, it.explanation, it.question_type ] }
        assert_equal [ [ "Vrai", true ] ], input.questions.first.answers.map { [ it.content, it.correct ] }
      end

      test "une erreur de structure posée sur « questions[1] » se traduit sans lire d'attribut de ce nom" do
        input = ExerciseInput.new(title: "Méiose", exercise_type: "fixation")
        input.errors.add(:"questions[1]", :wrong_correct_count)

        assert_equal [ I18n.t("activemodel.errors.models.dtos/assessment/exercise_input.attributes.questions.wrong_correct_count") ],
                     input.errors[:"questions[1]"]
        assert_equal "Méiose", input.read_attribute_for_validation(:title)
      end
    end
  end
end
