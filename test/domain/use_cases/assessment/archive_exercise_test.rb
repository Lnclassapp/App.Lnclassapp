require "test_helper"

module UseCases
  module Assessment
    class ArchiveExerciseTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      TEAM = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")

      # Le port n'expose aucune suppression : archiver ne fait que poser le statut (ADR-0036).
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

      def archive(actor: TEAM, public_id: "ExErCiCe000040", status: "published")
        exercise = Entities::Assessment::Exercise.new(id: 40, public_id: "ExErCiCe000040", essential_id: 9, title: "Méiose",
                                                      exercise_type: "fixation", status:, parents_published: false)
        @exercises = FakeExercises.new(exercise)
        @audit = FakeAudit.new
        ArchiveExercise.new(exercises: @exercises, audit_log: @audit, transaction: FakeTransaction.new,
                            policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                       .call(actor:, public_id:)
      end

      test "archive un exercice publié, même sous une fiche essentielle dépubliée, et le journalise" do
        result = archive

        assert result.success?
        assert_equal "archived", result.value.status
        assert_equal [ [ 40, "archived", NOW ] ], @exercises.transitions
        assert_equal [ { action: "content.archived", actor_id: 7, at: NOW, subject_type: "Exercise", subject_id: 40,
                         metadata: { public_id: "ExErCiCe000040" } } ], @audit.events
      end

      test "un brouillon ou un exercice déjà archivé ne s'archive pas" do
        %w[draft archived].each do |status|
          assert_equal [ :conflict, { base: [ :transition_not_allowed ] } ], archive(status:).then { [ it.code, it.errors ] }
        end
        assert_empty @exercises.transitions
      end

      test "hors équipe, refus ; un exercice inconnu est introuvable" do
        assert_equal :forbidden, archive(actor: nil).code
        assert_empty @exercises.transitions
        assert_equal :not_found, archive(public_id: "inconnu").code
      end
    end
  end
end
