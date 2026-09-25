require "test_helper"

module UseCases
  module Assessment
    class PublishExerciseTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")

      # Comme le repository : la transition pose le statut, l'exercice relu le porte.
      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        attr_reader :transitions

        def initialize(exercise)
          @exercise = exercise
          @transitions = []
        end

        def find_by_public_id(public_id:)
          @exercise if public_id == @exercise.public_id
        end

        def transition(id:, to:, at:)
          @transitions << [ id, to, at ]
          @exercise.status = to
          true
        end
      end

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :events

        def record(**event) = (@events ||= []) << event
      end

      def exercise(status:, parents_published:, questions:)
        answers = [ Entities::Assessment::Answer.new(id: 1, position: 1, content: "A", correct: true),
                    Entities::Assessment::Answer.new(id: 2, position: 2, content: "B", correct: false) ]
        question = Entities::Assessment::Question.new(id: 3, position: 1, content: "Q", explanation: nil,
                                                      question_type: "single_choice", answers:)
        Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", essential_id: 9, title: "Méiose",
                                           exercise_type: "fixation", status:, parents_published:,
                                           questions: Array.new(questions, question))
      end

      def publish(actor: TEAM, public_id: "ExErCiCe000040", status: "draft", parents_published: true, questions: 2)
        @exercises = FakeExercises.new(exercise(status:, parents_published:, questions:))
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
        PublishExercise.new(exercises: @exercises, audit_log: @audit, transaction: @transaction,
                            policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                       .call(actor:, public_id:)
      end

      test "publie un brouillon complet dont la fiche essentielle est publiée, et le journalise" do
        result = publish

        assert result.success?
        assert_equal "published", result.value.status
        assert_equal [ [ 40, "published", NOW ] ], @exercises.transitions
        assert_equal [ { action: "content.published", actor_id: 7, at: NOW, subject_type: "Exercise", subject_id: 40,
                         metadata: { public_id: "ExErCiCe000040" } } ], @audit.events
        assert_equal 1, @transaction.calls
      end

      test "un exercice archivé se republie" do
        assert publish(status: "archived").success?
      end

      test "sans question, fiche essentielle non publiée, ou déjà publié : conflit, rien n'est écrit" do
        assert_equal [ :conflict, { base: [ :not_publishable ] } ], publish(questions: 0).then { [ it.code, it.errors ] }
        assert_equal [ :conflict, { base: [ :parent_not_published ] } ], publish(parents_published: false).then { [ it.code, it.errors ] }
        assert_equal [ :conflict, { base: [ :transition_not_allowed ] } ], publish(status: "published").then { [ it.code, it.errors ] }
        assert_empty @exercises.transitions
        assert_nil @audit.events
      end

      test "hors équipe, refus ; un exercice inconnu est introuvable" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, publish(actor: teacher).code
        assert_empty @exercises.transitions
        assert_equal :not_found, publish(public_id: "inconnu").code
      end
    end
  end
end
