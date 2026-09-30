require "test_helper"
load Rails.root.join("script/ci/runner/rerun_expired").to_s unless defined?(RerunExpired)

# ADR-0068 : a pull request waits up to 48 hours for the owner's machine. GitHub fails a job queued 24 hours;
# the machine re-runs such a run once, if what it tested is still current. A red test is never re-run.
class CiRerunExpiredTest < ActiveSupport::TestCase
  REPOSITORY = "Lnclassapp/App.Lnclassapp"
  NOW = Time.utc(2026, 10, 2, 12)

  def run_data(id:, created: NOW - 25 * 3600, attempt: 1, conclusion: "failure", event: "pull_request", pulls: [ 7 ])
    { "id" => id, "run_attempt" => attempt, "conclusion" => conclusion, "created_at" => created.iso8601,
      "event" => event, "head_sha" => "abc", "head_branch" => "feature/x",
      "pull_requests" => pulls.map { { "number" => it } } }
  end

  def expired_job(created) = { "runner_name" => "", "created_at" => created.iso8601, "completed_at" => (created + 24 * 3600).iso8601 }

  def red_job(created) = { "runner_name" => "machine-lnclass-1", "created_at" => created.iso8601, "completed_at" => (created + 180).iso8601 }

  def subject(runs:, jobs:, pulls: {}, branches: {}, reruns: [], rerun: ->(id) { reruns << id })
    responses = { "repos/#{REPOSITORY}/actions/workflows/ci.yml/runs?status=completed&created=>=2026-09-30T12:00:00Z&per_page=100" => { "workflow_runs" => runs } }
    jobs.each { |id, list| responses["repos/#{REPOSITORY}/actions/runs/#{id}/jobs?per_page=100"] = { "jobs" => list } }
    pulls.each { |number, pull| responses["repos/#{REPOSITORY}/pulls/#{number}"] = pull }
    branches.each { |name, branch| responses["repos/#{REPOSITORY}/branches/#{name}"] = branch }
    api = ->(path) { responses.fetch(path) { flunk "appel inattendu : #{path}" } }

    RerunExpired.new(repository: REPOSITORY, api:, rerun:, now: NOW)
  end

  def open_pull(sha = "abc") = { "state" => "open", "head" => { "sha" => sha } }

  test "a run whose job waited 24 hours for the machine is re-run once, when its pull request has not moved" do
    reruns = []
    created = NOW - 25 * 3600
    result = subject(runs: [ run_data(id: 1, created:) ], jobs: { 1 => [ expired_job(created) ] }, pulls: { 7 => open_pull }, reruns:).call

    assert_equal [ 1 ], reruns
    assert_equal [ { id: 1, branch: "feature/x", status: :rerun } ], result
  end

  test "a dry run lists the run without re-running it" do
    reruns = []
    created = NOW - 25 * 3600
    result = subject(runs: [ run_data(id: 1, created:) ], jobs: { 1 => [ expired_job(created) ] }, pulls: { 7 => open_pull }, reruns:).call(dry_run: true)

    assert_empty reruns
    assert_equal [ { id: 1, branch: "feature/x", status: :would_rerun } ], result
  end

  test "a red test, a second attempt, a success or a run older than 48 hours is never re-run" do
    created = NOW - 25 * 3600
    runs = [ run_data(id: 1, created:), run_data(id: 2, created:, attempt: 2), run_data(id: 3, created:, conclusion: "success"),
             run_data(id: 4, created: NOW - 49 * 3600) ]

    assert_empty subject(runs:, jobs: { 1 => [ red_job(created) ] }, pulls: { 7 => open_pull }).candidates
  end

  test "a run cancelled before any runner took it, but after less than 23 hours, is not a timeout" do
    created = NOW - 25 * 3600
    cancelled = { "runner_name" => nil, "created_at" => created.iso8601, "completed_at" => (created + 600).iso8601 }

    assert_empty subject(runs: [ run_data(id: 1, created:, conclusion: "cancelled") ], jobs: { 1 => [ cancelled ] }, pulls: { 7 => open_pull }).candidates
  end

  test "a run whose pull request is closed or has a new head is not re-run" do
    created = NOW - 25 * 3600
    runs = [ run_data(id: 1, created:, pulls: [ 7 ]), run_data(id: 2, created:, pulls: [ 8 ]), run_data(id: 3, created:, pulls: [ 9 ]) ]
    jobs = { 1 => [ expired_job(created) ], 2 => [ expired_job(created) ], 3 => [ expired_job(created) ] }
    pulls = { 7 => { "state" => "closed", "head" => { "sha" => "abc" } }, 8 => open_pull("def"), 9 => nil }

    assert_empty subject(runs:, jobs:, pulls:).candidates
  end

  test "a push run is re-run only while its branch still points at the commit it tested" do
    created = NOW - 25 * 3600
    runs = [ run_data(id: 1, created:, event: "push", pulls: []) ]
    jobs = { 1 => [ expired_job(created) ] }

    assert_equal [ 1 ], subject(runs:, jobs:, branches: { "feature/x" => { "commit" => { "sha" => "abc" } } }).candidates.map { it["id"] }
    assert_empty subject(runs:, jobs:, branches: { "feature/x" => { "commit" => { "sha" => "new" } } }).candidates
  end

  test "an unreadable answer from GitHub re-runs nothing instead of raising" do
    created = NOW - 25 * 3600
    assert_empty subject(runs: [], jobs: {}).candidates

    assert_empty subject(runs: [ run_data(id: 1, created:) ], jobs: { 1 => nil }, pulls: { 7 => open_pull }).candidates
  end

  test "a re-run GitHub refuses is reported, not hidden" do
    created = NOW - 25 * 3600
    refusing = subject(runs: [ run_data(id: 1, created:) ], jobs: { 1 => [ expired_job(created) ] }, pulls: { 7 => open_pull },
                       rerun: ->(_) { false })

    assert_equal [ { id: 1, branch: "feature/x", status: :refused } ], refusing.call
  end
end
