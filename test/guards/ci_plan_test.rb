# Pure Ruby, no Rails boot: bin/ci is one list of steps, played whole by the one job of the GitHub workflow
# (feuille-de-route §2, garde-fou n° 4; ADR-0064, ADR-0069). The rules that keep the GitHub minutes within the quota
# fail here, in the lint group, before any test runs.
require "minitest/autorun"
require "yaml"
load File.expand_path("../../config/ci.rb", __dir__) unless defined?(CI_PLAN)

class CiPlanTest < Minitest::Test
  GITHUB = File.expand_path("../../.github", __dir__)
  WORKFLOW = File.join(GITHUB, "workflows/ci.yml")

  def workflow = YAML.safe_load_file(WORKFLOW, aliases: true)

  def jobs = workflow.fetch("jobs")

  # YAML reads the key `on` as true.
  def triggers = workflow.fetch(true)

  def full_run = CI_PLAN.steps_for(nil)

  # ADR-0069 : each job pays its start and its rounding to the minute. One job, « ci », plays the whole bin/ci:
  # no group left out, none played twice, nothing split across jobs.
  def test_one_job_named_ci_plays_the_whole_bin_ci
    assert_equal [ "ci" ], jobs.keys
    job = jobs.fetch("ci")
    assert_equal "ci", job["name"]
    assert_equal 1, job.fetch("steps").count { it["run"] == "bin/ci" }, "« ci » lance bin/ci une fois"
    assert_nil job.dig("env", "CI_GROUP"), "« ci » joue tout bin/ci, pas un groupe"
    assert_nil job["strategy"], "pas de matrice : un seul job"
  end

  # ADR-0069 : 45 % of the runs were pushes that merged a tree their pull request had already tested.
  # Pull requests only, and a draft waits until it is ready for review.
  def test_the_workflow_runs_on_ready_pull_requests_only
    assert_equal [ "pull_request" ], triggers.keys
    assert_includes triggers.dig("pull_request", "types"), "ready_for_review"
    assert_equal "${{ !github.event.pull_request.draft }}", jobs.dig("ci", "if")
  end

  # ADR-0069 : a tree that already got a green « ci » is not replayed; only a run that played the checks proves it.
  def test_a_tested_tree_is_not_replayed_and_a_played_run_publishes_its_proof
    steps = jobs.dig("ci", "steps")
    proof = steps.index { it["id"] == "proof" }
    suite = steps.index { it["run"] == "bin/ci" }

    assert proof && proof < suite, "la preuve d'arbre passe avant la suite"
    assert_equal "script/ci/tested_tree", steps[proof]["run"]
    assert_equal "steps.proof.outputs.tested != 'true'", steps.find { it["id"] == "changes" }["if"]
    publish = steps.find { it.dig("with", "name").to_s.start_with?("ci-tree-") }
    assert_equal "steps.changes.outputs.code == 'true'", publish["if"]
  end

  # ADR-0067 : the screen budgets seed 312 000 sessions; they run before each recette, never in bin/ci.
  def test_the_screen_budgets_stay_out_of_bin_ci
    played = full_run.map(&:command).join(" ")

    refute_empty CiPlan.files("test/performance/**/*_budget_test.rb")
    CiPlan.files("test/performance/**/*_budget_test.rb").each { refute_includes played, it }
    assert_includes played, "test/performance/catalog/import_course_tree_performance_test.rb"
  end

  # ADR-0069 : Dependabot follows the road of any change, Develop then the promotions, one grouped pull request
  # per ecosystem (17 of the 43 runs of 2026-10-01 were its eight pull requests and their merges on main).
  def test_dependabot_targets_develop_with_one_grouped_pull_request
    updates = YAML.safe_load_file(File.join(GITHUB, "dependabot.yml")).fetch("updates")

    refute_empty updates
    updates.each do |update|
      assert_equal "Develop", update["target-branch"], update["package-ecosystem"]
      assert_equal [ [ "*" ] ], update.fetch("groups", {}).values.map { it["patterns"] }, update["package-ecosystem"]
    end
  end

  # A service container (PostgreSQL, superuser with a known password) is published on the loopback only.
  def test_service_containers_are_published_on_the_loopback_only
    ports = jobs.values.flat_map { (it["services"] || {}).values.flat_map { it["ports"] || [] } }

    refute_empty ports
    ports.each { assert_match(/\A127\.0\.0\.1:/, it.to_s, "port « #{it} » publié sur toutes les interfaces") }
  end

  def test_the_split_is_deterministic_and_puts_the_longest_file_alone
    plan = CiPlan.define { sharded("demo", files: %w[a b c d]) { |files, _| step "x", files.join(" ") } }
    timings = { "a" => 10.0, "b" => 4.0, "c" => 3.0, "d" => 2.0 }

    assert_equal [ %w[a], %w[b c d] ], plan.split("demo", 2, timings:)
    assert_equal plan.split("demo", 2, timings:), plan.split("demo", 2, timings: timings.to_a.reverse.to_h)
  end

  def test_a_file_without_timing_weighs_the_median
    plan = CiPlan.define { sharded("demo", files: %w[a b c new]) { |files, _| step "x", files.join(" ") } }

    assert_equal [ %w[a], %w[b c new] ], plan.split("demo", 2, timings: { "a" => 9.0, "b" => 1.0, "c" => 2.0 })
  end

  def test_an_unknown_group_or_part_fails_loudly_instead_of_playing_nothing
    [ "lnit", "system:5/4", "system:0/4", "lint:1/2" ].each do |selection|
      assert_raises(CiPlan::SelectionError, selection) { CI_PLAN.steps_for(selection) }
    end
  end

  def test_setup_prepares_the_database_only_for_the_groups_that_use_it
    assert_equal "bin/setup --skip-server --skip-db", CI_PLAN.steps_for("lint").first.command
    assert_equal "bin/setup --skip-server", CI_PLAN.steps_for("system:1/4").first.command
    assert_equal "bin/setup --skip-server", full_run.first.command
  end

  def test_a_group_list_keeps_the_order_of_the_full_run
    assert_equal CI_PLAN.steps_for("unit,seeds").map(&:title), CI_PLAN.steps_for("seeds, unit").map(&:title)
  end
end
