require "test_helper"

module Repositories
  module Assessment
    class KnowledgeGapRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = KnowledgeGapRepository.new
        @student = create_student
        @essential = create_essential
        @exercise = create_exercise(essential: @essential)
        @failed = create_session(student: @student, exercise: @exercise, status: "completed", score_percent: 30)
        @at = Time.zone.parse("2026-09-25 10:00")
      end

      def open_gap
        @repository.open(student_id: @student.id, essential_id: @essential.id, source_session_id: @failed.id, at: @at)
      end

      test "ouvre une lacune en attente et la retrouve" do
        gap = open_gap

        assert_instance_of Entities::Assessment::KnowledgeGap, gap
        assert_equal [ "pending", 1 ], [ gap.status, gap.failed_sessions_count ]
        assert_equal gap, @repository.pending_for(student_id: @student.id, essential_id: @essential.id)
        assert_equal gap, @repository.find(id: gap.id)
        assert_nil @repository.find(id: 0)
      end

      test "une seconde ouverture renvoie la lacune déjà en attente" do
        first = open_gap

        assert_equal first.id, open_gap.id
        assert_equal 1, Orm::KnowledgeGap.where(student: @student).count
      end

      test "compte les échecs, puis résout la lacune une seule fois" do
        gap = open_gap
        remediation = create_session(student: @student, exercise: @exercise, status: "completed", score_percent: 90)

        assert @repository.increment(id: gap.id)
        assert_equal 2, @repository.find(id: gap.id).failed_sessions_count
        assert @repository.resolve(id: gap.id, status: "remediated", session_id: remediation.id, at: @at)
        @repository.resolve(id: gap.id, status: "self_corrected", session_id: remediation.id, at: @at + 1)

        assert_equal [ "remediated", remediation.id, @at ],
                     Orm::KnowledgeGap.find(gap.id).attributes.values_at("status", "resolved_by_session_id", "resolved_at")
        assert_nil @repository.pending_for(student_id: @student.id, essential_id: @essential.id)
      end
    end
  end
end
