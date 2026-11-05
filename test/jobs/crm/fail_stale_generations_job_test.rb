require "test_helper"

# CA-25 (ADR-XXXX modèles de langage) : toutes les 15 minutes, les générations restées « en attente » (worker tué, file perdue) sont fermées
# pour toutes les écoles et leur audio est purgé, même si personne ne revient sur l'école.
module Crm
  class FailStaleGenerationsJobTest < ActiveSupport::TestCase
    setup do
      @repository = Repositories::Crm::GenerationRepository.new
      @user = create_team_member(team_role: "field")
    end

    def pending(school, kind)
      @repository.create_pending(generation: Entities::Crm::Generation.new(
        public_id: nil, school_id: school.id, kind:, status: "pending", requested_by_id: @user.id, follow_up_id: nil,
        input_fingerprint: nil, content: nil, error_code: nil, model: nil, input_tokens: nil, output_tokens: nil, duration_ms: nil
      )).value
    end

    test "it closes the stale pending generations of every school and kind, and purges their audio" do
      first = pending(create_school, "dictation")
      second = pending(create_school, "briefing")
      recent = pending(create_school, "pedagogy_report")
      Orm::CrmGeneration.find_by(public_id: first.public_id).audio.attach(io: StringIO.new("OCTETS"), filename: "dictation.webm", content_type: "audio/webm")
      Orm::CrmGeneration.where(public_id: [ first.public_id, second.public_id ]).update_all(created_at: 10.minutes.ago)

      FailStaleGenerationsJob.perform_now

      assert_equal [ "failed", "timeout" ], @repository.find_by_public_id(public_id: first.public_id).to_h.values_at(:status, :error_code)
      assert @repository.find_by_public_id(public_id: second.public_id).failed?
      assert @repository.find_by_public_id(public_id: recent.public_id).pending?
      assert_not Orm::CrmGeneration.find_by(public_id: first.public_id).audio.attached?
    end

    test "it runs every 15 minutes" do
      task = Rails.application.config_for(:recurring, env: "production").fetch(:fail_stale_crm_generations)

      assert_equal({ class: "Crm::FailStaleGenerationsJob", queue: "default", schedule: "every 15 minutes" }, task)
    end
  end
end
