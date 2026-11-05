require "test_helper"

# ADR-XXXX (modèles de langage) §4: a generation is created pending (one per school and kind), read back as an entity,
# completed with its model, tokens and duration, or marked failed with an error code.
module Repositories
  module Crm
    class GenerationRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = GenerationRepository.new
        @school = create_school
        @user = create_team_member(team_role: "field")
      end

      def generation(kind: "briefing", school_id: @school.id, input_fingerprint: "a" * 64)
        Entities::Crm::Generation.new(public_id: nil, school_id:, kind:, status: "pending", requested_by_id: @user.id, follow_up_id: nil,
                                      input_fingerprint:, content: nil, error_code: nil, model: nil, input_tokens: nil,
                                      output_tokens: nil, duration_ms: nil)
      end

      test "create_pending returns the pending entity with a public id" do
        result = @repository.create_pending(generation: generation)

        assert result.success?
        assert_equal 14, result.value.public_id.length
        assert result.value.pending?
        assert_equal [ @school.id, "briefing", @user.id, "a" * 64 ], result.value.to_h.values_at(:school_id, :kind, :requested_by_id, :input_fingerprint)
      end

      test "the entity carries the creation time" do
        created = @repository.create_pending(generation: generation).value

        assert_in_delta Time.current, created.created_at, 5
        assert_equal created.created_at, @repository.find_by_public_id(public_id: created.public_id).created_at
      end

      test "only one pending generation per school and kind: the second is a conflict" do
        @repository.create_pending(generation: generation)

        result = @repository.create_pending(generation: generation)

        assert result.failure?
        assert_equal :conflict, result.code
        assert_equal 1, Orm::CrmGeneration.where(school_id: @school.id, kind: "briefing").count
      end

      test "another kind, or another school, is not a conflict" do
        @repository.create_pending(generation: generation)

        assert @repository.create_pending(generation: generation(kind: "pedagogy_report")).success?
        assert @repository.create_pending(generation: generation(school_id: create_school.id)).success?
      end

      test "a new generation is possible once the previous one is finished" do
        first = @repository.create_pending(generation: generation).value
        @repository.mark_failed(public_id: first.public_id, error_code: "timeout", duration_ms: 30_000)

        assert @repository.create_pending(generation: generation).success?
      end

      test "find_by_public_id and pending_for read back the entity, or nil" do
        created = @repository.create_pending(generation: generation).value

        assert_equal created, @repository.find_by_public_id(public_id: created.public_id)
        assert_equal created, @repository.pending_for(school_id: @school.id, kind: "briefing")
        assert_nil @repository.find_by_public_id(public_id: "unknown-public")
        assert_nil @repository.pending_for(school_id: @school.id, kind: "dictation")
      end

      test "complete stores the content, the model, the tokens and the duration" do
        created = @repository.create_pending(generation: generation).value

        result = @repository.complete(public_id: created.public_id, content: "Fiche", model: "fake/model", input_tokens: 10, output_tokens: 20, duration_ms: 1200)

        assert result.success?
        assert result.value.done?
        assert_equal [ "Fiche", "fake/model", 10, 20, 1200 ], result.value.to_h.values_at(:content, :model, :input_tokens, :output_tokens, :duration_ms)
        assert_nil @repository.pending_for(school_id: @school.id, kind: "briefing")
      end

      test "mark_failed stores the error code and the duration" do
        created = @repository.create_pending(generation: generation).value

        result = @repository.mark_failed(public_id: created.public_id, error_code: "provider_error", duration_ms: 800)

        assert result.value.failed?
        assert_equal [ "provider_error", 800 ], result.value.to_h.values_at(:error_code, :duration_ms)
      end

      test "complete and mark_failed write only a pending row: a finished generation is never overwritten" do
        created = @repository.create_pending(generation: generation).value
        @repository.complete(public_id: created.public_id, content: "Fiche", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)

        assert_equal :conflict, @repository.mark_failed(public_id: created.public_id, error_code: "timeout", duration_ms: 1).code
        assert_equal :conflict, @repository.complete(public_id: created.public_id, content: "Autre", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1).code
        kept = @repository.find_by_public_id(public_id: created.public_id)
        assert_equal [ "done", "Fiche", nil ], [ kept.status, kept.content, kept.error_code ]
      end

      test "fail_stale closes the old pending rows with a timeout and purges their audio" do
        old = @repository.create_pending(generation: generation(kind: "dictation")).value
        Orm::CrmGeneration.find_by(public_id: old.public_id).audio.attach(io: StringIO.new("OCTETS"), filename: "dictation.webm", content_type: "audio/webm")
        Orm::CrmGeneration.where(public_id: old.public_id).update_all(created_at: 10.minutes.ago)
        recent = @repository.create_pending(generation: generation(kind: "briefing")).value

        assert_equal 1, @repository.fail_stale(school_id: @school.id, kind: "dictation", before: 2.minutes.ago)

        failed = @repository.find_by_public_id(public_id: old.public_id)
        assert_equal [ "failed", "timeout" ], [ failed.status, failed.error_code ]
        assert_not Orm::CrmGeneration.find_by(public_id: old.public_id).audio.attached?
        assert @repository.find_by_public_id(public_id: recent.public_id).pending?
      end

      test "fail_stale leaves a recent pending row and other schools alone, and covers every school when none is given" do
        other_school = create_school
        mine = @repository.create_pending(generation: generation).value
        theirs = @repository.create_pending(generation: generation(school_id: other_school.id)).value
        Orm::CrmGeneration.update_all(created_at: 10.minutes.ago)

        assert_equal 0, @repository.fail_stale(school_id: @school.id, kind: "briefing", before: 20.minutes.ago)
        assert_equal 1, @repository.fail_stale(school_id: @school.id, kind: "briefing", before: 2.minutes.ago)
        assert @repository.find_by_public_id(public_id: theirs.public_id).pending?
        assert @repository.find_by_public_id(public_id: mine.public_id).failed?

        assert_equal 1, @repository.fail_stale(school_id: nil, kind: nil, before: 2.minutes.ago)
        assert @repository.find_by_public_id(public_id: theirs.public_id).failed?
      end

      test "complete and mark_failed on an unknown id are not_found" do
        assert_equal :not_found, @repository.complete(public_id: "unknown-public", content: "x", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1).code
        assert_equal :not_found, @repository.mark_failed(public_id: "unknown-public", error_code: "timeout", duration_ms: 1).code
      end

      test "latest_done returns the newest done generation with the same fingerprint only" do
        old = @repository.create_pending(generation: generation).value
        @repository.complete(public_id: old.public_id, content: "Ancienne", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
        recent = @repository.create_pending(generation: generation).value
        @repository.complete(public_id: recent.public_id, content: "Récente", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
        other = @repository.create_pending(generation: generation(input_fingerprint: "b" * 64)).value
        @repository.complete(public_id: other.public_id, content: "Autre", model: "m", input_tokens: 1, output_tokens: 1, duration_ms: 1)
        Orm::CrmGeneration.where(public_id: old.public_id).update_all(created_at: 2.days.ago)

        assert_equal "Récente", @repository.latest_done(school_id: @school.id, kind: "briefing", input_fingerprint: "a" * 64).content
        assert_nil @repository.latest_done(school_id: @school.id, kind: "briefing", input_fingerprint: "c" * 64)
        assert_nil @repository.latest_done(school_id: @school.id, kind: "dictation", input_fingerprint: "a" * 64)
        assert_nil @repository.latest_done(school_id: @school.id, kind: "briefing", input_fingerprint: nil)
      end
    end
  end
end
