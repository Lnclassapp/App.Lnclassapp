require "test_helper"

class Shared::PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  def blob(created_at:)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "x.txt").tap { |b| b.update_columns(created_at:) }
  end

  test "purges unattached blobs older than 48 hours, and only those" do
    stale = blob(created_at: 49.hours.ago)
    recent = blob(created_at: 47.hours.ago)

    Shared::PurgeUnattachedBlobsJob.perform_now

    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ stale ])
    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob
    assert ActiveStorage::Blob.exists?(recent.id)
  end
end
