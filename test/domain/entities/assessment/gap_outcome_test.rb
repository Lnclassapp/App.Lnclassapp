require "test_helper"

module Entities
  module Assessment
    # ADR-0101 §4.3: what a completed session did to its sheet, read from the existing columns only. It speaks of this
    # session: a sheet lifted by another session says nothing on this result.
    class GapOutcomeTest < ActiveSupport::TestCase
      Gap = Data.define(:id, :status, :source_session_id, :resolved_by_session_id)

      def outcome(gap, session_id: 10, kind: "standard", knowledge_gap_id: nil)
        GapOutcome.call(session_id:, session_kind: kind, knowledge_gap_id:, gap:)
      end

      def gap(status: "pending", source: 1, resolved_by: nil) = Gap.new(id: 7, status:, source_session_id: source, resolved_by_session_id: resolved_by)

      test "no gap linked to the session: nil" do
        assert_nil outcome(nil)
        assert_nil outcome(nil, kind: "remediation", knowledge_gap_id: 7)
      end

      test "the session opened the gap: :opened" do
        assert_equal :opened, outcome(gap(source: 10))
      end

      test "the session lifted the gap: :lifted, remediated or self-corrected alike" do
        assert_equal :lifted, outcome(gap(status: "remediated", resolved_by: 10), kind: "remediation", knowledge_gap_id: 7)
        assert_equal :lifted, outcome(gap(status: "self_corrected", resolved_by: 10))
      end

      test "a remediation that left its gap pending: :still_pending" do
        assert_equal :still_pending, outcome(gap, kind: "remediation", knowledge_gap_id: 7)
      end

      test "a remediation whose gap another session lifted: nil" do
        assert_nil outcome(gap(status: "remediated", resolved_by: 11), kind: "remediation", knowledge_gap_id: 7)
      end

      test "a pending gap that is not the one the session targets, or a standard session: nil" do
        assert_nil outcome(gap, kind: "remediation", knowledge_gap_id: 8)
        assert_nil outcome(gap, kind: "standard", knowledge_gap_id: 7)
      end
    end
  end
end
