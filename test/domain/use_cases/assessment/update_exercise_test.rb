require "test_helper"

module UseCases
  module Assessment
    class UpdateExerciseTest < ActiveSupport::TestCase
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      # Comme le repository : remplacer les questions n'est permis qu'avant toute session (ADR-0036).
      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        attr_reader :updates

        def initialize(exercise, sessions:, refuse: false)
          @exercise = exercise
          @sessions = sessions
          @refuse = refuse
          @updates = []
        end

        def find_by_public_id(public_id:)
          @exercise if public_id == @exercise.public_id
        end

        def has_sessions?(exercise_id:) = @sessions && exercise_id == @exercise.id

        def update(exercise:, replace_questions:)
          raise FakeTransaction::Refused if @refuse

          @updates << [ exercise, replace_questions ]
          exercise
        end
      end

      def stored(status: "draft")
        question = Question.new(id: 11, position: 1, content: "Ancienne question", explanation: nil, question_type: "true_false",
                                answers: [ Answer.new(id: 21, position: 1, content: "Vrai", correct: true),
                                           Answer.new(id: 22, position: 2, content: "Faux", correct: false) ])
        Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", essential_id: 9, position: 3, author_id: 5,
                                           title: "Méiose", description: "Ancienne consigne", exercise_type: "fixation",
                                           status:, parents_published: true, questions: [ question ])
      end

      NEW_QUESTION = { "0" => { content: "Nouvelle question", question_type: "single_choice",
                                answers_attributes: { "0" => { content: "A", correct: "1" }, "1" => { content: "B", correct: "0" } } } }.freeze

      def update(public_id: "ExErCiCe000040", actor: TEAM, sessions: false, status: "draft", refuse: false, **fields)
        @exercises = FakeExercises.new(stored(status:), sessions:, refuse:)
        @transaction = FakeTransaction.new
        dto = Dtos::Assessment::ExerciseInput.from_params(
          { title: "Méiose II", description: "Nouvelle consigne", exercise_type: "fixation", questions_attributes: NEW_QUESTION }
            .merge(fields).with_indifferent_access
        )
        UpdateExercise.new(exercises: @exercises, transaction: @transaction, policy: Policies::Catalog::ManageContentPolicy.new)
                      .call(actor:, public_id:, dto:)
      end

      test "sans session, la question remplacée disparaît au profit de la nouvelle" do
        result = update

        assert result.success?
        exercise, replace = @exercises.updates.sole
        assert replace
        assert_equal [ 40, "ExErCiCe000040", 9, 3, 5, "draft" ],
                     [ exercise.id, exercise.public_id, exercise.essential_id, exercise.position, exercise.author_id, exercise.status ]
        assert_equal [ "Méiose II", "Nouvelle consigne" ], [ exercise.title, exercise.description ]
        assert_equal [ "Nouvelle question" ], exercise.questions.map(&:content)
        assert_equal 1, @transaction.attempts
      end

      test "après une session, titre et description se modifient, les questions restent telles quelles" do
        result = update(sessions: true, questions_attributes: nil)

        assert result.success?
        exercise, replace = @exercises.updates.sole
        assert_not replace
        assert_equal "Méiose II", exercise.title
        assert_equal [ 11 ], exercise.questions.map(&:id)
      end

      test "après une session, toute question envoyée ou tout changement de type est refusé : questions verrouillées" do
        [ { sessions: true }, { sessions: true, questions_attributes: nil, exercise_type: "evaluation" } ].each do |options|
          result = update(**options)

          assert_equal [ :invalid, { base: [ :questions_locked ] } ], [ result.code, result.errors ]
        end
        assert_empty @exercises.updates
      end

      test "hors équipe, rien ne change, même pour un exercice inconnu" do
        student = Entities::Identity::Actor.new(user_id: 8, role: :student)

        assert_equal :forbidden, update(actor: student).code
        assert_equal :forbidden, update(actor: nil, public_id: "inconnu").code
        assert_empty @exercises.updates
      end

      test "un exercice inconnu est introuvable" do
        assert_equal :not_found, update(public_id: "inconnu").code
      end

      test "saisie incomplète, titre trop long ou question mal construite : rien n'est écrit" do
        blank = update(title: "")
        long = update(title: "a" * 151)
        wrong = update(questions_attributes: { "0" => NEW_QUESTION["0"].merge(question_type: "multiple_correct_2") })

        assert_equal [ :invalid, [ :title ] ], [ blank.code, blank.errors.keys ]
        assert_equal [ :invalid, [ :title ] ], [ long.code, long.errors.keys ]
        assert_equal [ :invalid, { "questions[0]": %i[too_few_answers wrong_correct_count] } ], [ wrong.code, wrong.errors ]
        assert_empty @exercises.updates
      end

      test "un exercice publié garde au moins une question ; un brouillon peut n'en avoir aucune" do
        published = update(status: "published", questions_attributes: nil)

        assert_equal [ :invalid, { questions: [ :needed_while_published ] } ], [ published.code, published.errors ]
        assert update(status: "draft", questions_attributes: nil).success?
        assert update(status: "published").success?
      end

      test "une écriture refusée par la base est un conflit" do
        assert_equal [ :conflict, { base: [ :write_failed ] } ], update(refuse: true).then { [ it.code, it.errors ] }
      end
    end
  end
end
