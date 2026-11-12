require "test_helper"
require "open3"

module UseCases
  module Assessment
    # hors-connexion, Lot C (CA-6, CA-8) : de bout en bout, le paquet réellement servi (OfflinePackQuery) est corrigé par grader.js, la copie
    # qu'il range en file est synchronisée, et le serveur la recorrige à la même note. Les réponses de la table partagée sont posées sur
    # l'ordre d'affichage réel du paquet (la table a le sien) ; un écart de traduction (rang, graine, avoid) fait sortir une note différente.
    class SyncOfflineCopyParityTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 12, 12)
      UUID = "3f2b8a1e-5c4d-4e6f-9a7b-1c2d3e4f5a6b".freeze
      TABLE = JSON.parse(Rails.root.join("test/fixtures/files/offline/grading_cases.json").read)
      GRADER = Rails.root.join("app/javascript/offline/grader.js")
      Clock = Data.define(:now)
      Access = Data.define(:blocked) { def blocked? = blocked }

      class OpenAccess
        def call(student_id:, at:) = Access.new(false)
      end

      GRADED = TABLE["questions"].reject { %w[written notebook].include?(it.dig("question", "question_type")) }

      GRADED.each do |entry|
        test "copie locale puis synchronisée : « #{entry["name"]} » a la même note des deux côtés" do
          exercise, question = exercise_for(entry["question"])
          student = create_student_for(exercise.course)
          pack = JSON.parse(Queries::Assessment::OfflinePackQuery.new.call(public_id: exercise.public_id).questions.to_json).first
          response = on_real_sheet(entry, pack)

          local = grade_locally([ pack ], { pack["id"].to_s => response })
          result = sync(student, exercise, local.fetch("answers"))

          assert_predicate result, :success?, result.errors.inspect
          row = Orm::ExerciseSession.find_by!(client_copy_id: UUID)
          assert_equal local.fetch("percent"), row.score_percent, "le serveur note autrement que le correcteur local"
          assert_equal entry.dig("expected", "correct"), local.fetch("results").first.fetch("correct")
          assert_equal entry.dig("expected", "correct"), Orm::QuestionAttempt.find_by!(question_id: question.id).correct if local.fetch("answers").any?
        end
      end

      private

      def exercise_for(raw)
        exercise = create_exercise(questions: 0)
        question = exercise.questions.create!(position: 1, content: raw["content"], question_type: raw["question_type"], points: raw["points"],
                                              unit: raw["unit"], numeric_tolerance: raw["numeric_tolerance"])
        raw["answers"].each do |answer|
          question.answers.create!(answer.slice("position", "content", "match_content", "correct", "blank").compact)
        end
        [ exercise, question ]
      end

      # La table dit « place j de ma feuille » ; le paquet a sa propre feuille : on retrouve la place du même rang dans la feuille réelle.
      def on_real_sheet(entry, pack)
        table_display = entry["question"]["display"]
        real_display = pack["display"]
        place = lambda do |value|
          index = Integer(value, exception: false)
          rank = index && table_display && table_display[index]
          rank && real_display ? real_display.index(rank).to_s : value
        end
        response = entry["response"].deep_dup
        response["display_order"] = response["display_order"].map(&place) if response["display_order"]
        response["blanks"] = response["blanks"].transform_values(&place) if response["blanks"] && pack["kind"] == "select"
        response
      end

      def grade_locally(questions, responses)
        script = "const { gradeCopy } = await import(#{GRADER.to_s.to_json}); " \
                 "const input = JSON.parse(process.argv[1]); process.stdout.write(JSON.stringify(gradeCopy(input.questions, input.responses)))"
        out, status = Open3.capture2("node", "--no-warnings", "--input-type=module", "-e", script, { questions:, responses: }.to_json)
        assert_predicate status, :success?
        JSON.parse(out)
      end

      def sync(student, exercise, answers)
        digest = Queries::Assessment::OfflinePackQuery.new.call(public_id: exercise.public_id).digest
        token = Repositories::Assessment::OfflinePackSigner.new.sign(student_id: student.id, exercise_id: exercise.id, digest:, issued_at: NOW - 3600)
        use_case = SyncOfflineCopy.new(
          signer: Repositories::Assessment::OfflinePackSigner.new, exercises: Repositories::Assessment::ExerciseRepository.new,
          sessions: Repositories::Assessment::ExerciseSessionRepository.new, gaps: Repositories::Assessment::KnowledgeGapRepository.new,
          badges: Repositories::Assessment::BadgeRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
          assignments: Repositories::Classroom::AssignmentRepository.new, pending: Repositories::Assessment::PendingAssignmentRepository.new, policy: Policies::Assessment::StartSessionPolicy.new,
          transaction: Repositories::Shared::Transaction.new, clock: Clock.new(NOW), access: OpenAccess.new,
          current_digest: ->(model) { Queries::Assessment::OfflinePackQuery.new.call(public_id: model.public_id).digest }
        )
        dto = Dtos::Assessment::OfflineCopyInput.new(client_copy_id: UUID, exercise_public_id: exercise.public_id, pack_token: token,
                                                     started_at: (NOW - 1800).iso8601, submitted_at: (NOW - 600).iso8601, answers:)
        use_case.call(actor: Entities::Identity::Actor.new(user_id: student.id, role: :student), dto:)
      end
    end
  end
end
