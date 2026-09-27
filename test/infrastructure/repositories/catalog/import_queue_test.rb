require "test_helper"

module Repositories
  module Catalog
    class ImportQueueTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      class ProbeImportJob < ApplicationJob
        def perform(_report_id) = nil
      end

      test "chaque type d'import nomme son job, sans le charger au démarrage" do
        jobs = Rails.configuration.x.import_jobs

        assert_equal Entities::Catalog::ImportKind::KINDS.sort, jobs.keys.sort
        assert_equal "School::ImportSchoolsJob", jobs["schools"]
        assert jobs.values.all?(String)
      end

      test "résout le job du type à l'appel puis le met en file avec l'id du rapport" do
        configured = Rails.configuration.x.import_jobs
        Rails.configuration.x.import_jobs = configured.merge("schools" => ProbeImportJob.name)

        assert_enqueued_with(job: ProbeImportJob, args: [ 42 ]) do
          assert ImportQueue.new.enqueue(kind: "schools", report_id: 42)
        end
      ensure
        Rails.configuration.x.import_jobs = configured
      end

      test "un job pas encore livré ne lève qu'à la mise en file" do
        Rails.configuration.x.import_jobs.each_value do |name|
          next if name.safe_constantize

          assert_raises(NameError) { ImportQueue.new.enqueue(kind: Rails.configuration.x.import_jobs.key(name), report_id: 1) }
        end
      end
    end
  end
end
