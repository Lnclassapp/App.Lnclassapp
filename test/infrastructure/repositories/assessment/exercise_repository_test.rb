require "test_helper"

module Repositories
  module Assessment
    class ExerciseRepositoryTest < ActiveSupport::TestCase
      Answer = Entities::Assessment::Answer
      Question = Entities::Assessment::Question

      setup do
        @repository = ExerciseRepository.new
        @essential = create_essential
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def question(content, question_type: "true_false", answers: [ [ "Vrai", true ], [ "Faux", false ] ], position: nil)
        Question.new(id: nil, position:, content:, explanation: "Parce que.", question_type:,
                     answers: answers.map { |text, correct| Answer.new(id: nil, position: nil, content: text, correct:) })
      end

      def exercise(title: "Quiz", questions: [ question("La mitose donne deux cellules.") ], **attributes)
        Entities::Assessment::Exercise.new(essential_id: @essential.id, author_id: @essential.author_id, title:,
                                           exercise_type: "fixation", questions:, **attributes)
      end

      test "crée un exercice brouillon en fin de fiche, avec ses questions et propositions ordonnées" do
        create_exercise(essential: @essential)

        created = @repository.create(exercise: exercise(questions: [ question("Q1"), question("Q2") ]))

        assert_instance_of Entities::Assessment::Exercise, created
        assert_equal [ "draft", 2, 14 ], [ created.status, created.position, created.public_id.length ]
        assert_equal [ [ 1, "Q1" ], [ 2, "Q2" ] ], created.questions.map { [ it.position, it.content ] }
        assert_equal [ [ 1, "Vrai", true ], [ 2, "Faux", false ] ], created.questions.first.answers.map { [ it.position, it.content, it.correct ] }
        assert created.parents_published
        assert created.publishable?
      end

      test "garde la position et le statut fournis" do
        created = @repository.create(exercise: exercise(position: 9, status: "published", questions: [ question("Q", position: 4) ]))

        assert_equal [ 9, "published", 4 ], [ created.position, created.status, created.questions.first.position ]
      end

      test "relit un exercice par public_id avec la publication de ses parents, nil sinon" do
        draft_parent = create_exercise(essential: create_essential(status: "draft"))

        assert_not @repository.find_by_public_id(public_id: draft_parent.public_id).parents_published
        assert_nil @repository.find_by_public_id(public_id: "inconnu")
      end

      test "met à jour l'exercice seul, ou remplace aussi ses questions" do
        created = @repository.create(exercise: exercise)
        created.title = "Quiz révisé"
        created.questions = [ question("Nouvelle", question_type: "single_choice", answers: [ [ "A", false ], [ "B", true ] ]) ]

        kept = @repository.update(exercise: created, replace_questions: false)

        assert_equal "Quiz révisé", kept.title
        assert_equal [ "La mitose donne deux cellules." ], kept.questions.map(&:content)

        replaced = @repository.update(exercise: created, replace_questions: true)

        assert_equal [ "Nouvelle" ], replaced.questions.map(&:content)
        assert_equal 2, Orm::Answer.joins(:question).where(questions: { exercise_id: created.id }).count
      end

      test "publie en posant published_at une seule fois, archive en posant archived_at" do
        record = create_exercise(essential: @essential, status: "draft")

        assert @repository.transition(id: record.id, to: "published", at: @at)
        assert @repository.transition(id: record.id, to: "archived", at: @at + 1.day)
        @repository.transition(id: record.id, to: "published", at: @at + 2.days)

        assert_equal [ "published", @at, nil ], record.reload.attributes.values_at("status", "published_at", "archived_at")
        assert_raises(ArgumentError) { @repository.transition(id: record.id, to: "draft", at: @at) }
      end

      test "sait si un exercice a des sessions" do
        record = create_exercise(essential: @essential)

        assert_not @repository.has_sessions?(exercise_id: record.id)
        create_exercise_session(exercise: record)
        assert @repository.has_sessions?(exercise_id: record.id)
      end

      test "donne les clés de doublon, pour les fiches demandées ou toutes" do
        create_exercise(essential: @essential, title: "Quiz  Génétique")
        other = create_exercise(title: "Autre")

        assert_equal Set[[ @essential.id, "quiz genetique" ]], @repository.existing_keys(essential_ids: [ @essential.id ])
        assert_includes @repository.existing_keys, [ other.essential_id, "autre" ]
      end

      test "donne la prochaine position libre de chaque fiche" do
        create_exercise(essential: @essential, position: 3)
        empty = create_essential

        assert_equal({ @essential.id => 4, empty.id => 1 }, @repository.next_positions(essential_ids: [ @essential.id, empty.id ]))
      end
    end
  end
end
