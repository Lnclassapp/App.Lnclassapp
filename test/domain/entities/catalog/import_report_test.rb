require "test_helper"

module Entities
  module Catalog
    class ImportReportTest < ActiveSupport::TestCase
      def build(status)
        ImportReport.new(id: 1, public_id: "r", kind: "schools", status:, format_version: 1, total_count: 0,
                         imported_count: 0, skipped_count: 0, error_count: 0, processed_count: 0, details: {},
                         import_errors: [], imported_by_id: 2, started_at: nil, finished_at: nil)
      end

      test "en cours tant qu'il n'est ni terminé, ni rejeté, ni en échec" do
        %w[queued validating importing].each { |status| assert build(status).running?, status }
        %w[completed rejected failed].each { |status| assert_not build(status).running?, status }
        assert_equal ImportReport::RUNNING + %w[completed rejected failed], ImportReport::STATUSES
      end
    end
  end
end
