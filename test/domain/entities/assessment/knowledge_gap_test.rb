require "test_helper"

module Entities
  module Assessment
    class KnowledgeGapTest < ActiveSupport::TestCase
      test "en attente tant qu'elle n'est pas résolue" do
        gap = KnowledgeGap.new(id: 1, student_id: 2, essential_id: 3, status: "pending", failed_sessions_count: 1)

        assert gap.pending?
        assert_not gap.with(status: "remediated").pending?
        assert_equal %w[pending remediated self_corrected], KnowledgeGap::STATUSES
      end
    end
  end
end
