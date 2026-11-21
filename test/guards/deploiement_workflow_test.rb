# Pure Ruby, no Rails boot: the rules that keep the Hostinger token away from pull requests (ADR-0144,
# threat M1 to M9). A workflow that breaks one of them fails here, in the lint group, before it can leak a secret.
require "minitest/autorun"
require "yaml"

class DeploiementWorkflowTest < Minitest::Test
  WORKFLOWS = File.expand_path("../../.github/workflows", __dir__)
  DEPLOY = File.join(WORKFLOWS, "deploiement.yml")
  BRANCHES = %w[Develop Staging main].freeze
  SHA_PIN = %r{\A[\w.-]+/[\w.-]+(/[\w./-]+)?@[0-9a-f]{40}\z}
  SECRET = /\$\{\{\s*secrets\./

  def workflow = YAML.safe_load_file(DEPLOY, aliases: true)

  # YAML reads the key `on` as true.
  def triggers = workflow.fetch(true)

  def job = workflow.fetch("jobs").fetch("deploiement")

  def steps = job.fetch("steps")

  def deploys?(step) = step["run"].to_s.include?("deployer.py")

  def first_deploy = steps.index { |step| deploys?(step) }

  def test_no_workflow_uses_pull_request_target
    files = Dir[File.join(WORKFLOWS, "*.{yml,yaml}")]

    refute_empty files
    files.each do |file|
      keys = YAML.safe_load_file(file, aliases: true).fetch(true).then { |on| on.is_a?(Hash) ? on.keys : Array(on) }
      refute_includes keys.map(&:to_s), "pull_request_target", File.basename(file)
    end
  end

  def test_only_a_push_on_the_three_branches_and_a_manual_run_trigger_it
    assert_equal %w[push workflow_dispatch], triggers.keys.sort
    assert_equal BRANCHES.sort, triggers.dig("push", "branches").sort
    assert_equal BRANCHES.size, triggers.dig("push", "branches").size
    sha = triggers.dig("workflow_dispatch", "inputs", "sha")
    assert_equal true, sha["required"]
    assert_equal "string", sha["type"]
  end

  def test_permissions_are_empty_for_the_workflow_and_read_only_for_the_job
    assert_equal({}, workflow["permissions"])
    assert_equal({ "contents" => "read", "actions" => "read" }, job["permissions"])
  end

  def test_concurrency_is_per_branch_and_never_cancels
    assert_includes workflow.dig("concurrency", "group"), "github.ref_name"
    assert_equal false, workflow.dig("concurrency", "cancel-in-progress")
  end

  def test_the_environment_follows_the_branch_and_the_job_stays_in_this_repository
    expression = job["environment"]

    # github.ref, never ref_name: a tag named « main » must not reach production.
    refute_includes expression, "ref_name"
    assert_match(/github\.ref == 'refs\/heads\/main' && 'production'/, expression)
    assert_match(/github\.ref == 'refs\/heads\/Staging' && 'staging'/, expression)
    assert_match(/\|\| 'develop' \}\}\z/, expression)
    assert_includes job["if"], "github.repository == 'Lnclassapp/App.Lnclassapp'"
    assert_includes job["if"], %(fromJSON('["refs/heads/Develop","refs/heads/Staging","refs/heads/main"]'), github.ref)
    refute_includes job["if"], "ref_name"
  end

  def test_every_action_is_pinned_by_a_full_commit
    uses = steps.filter_map { |step| step["uses"] }

    refute_empty uses
    uses.each { |use| assert_match SHA_PIN, use }
  end

  def test_the_proof_of_the_tree_comes_before_any_deployer_call_and_spares_develop
    proof = steps.index { |step| step["run"].to_s.include?("script/ci/tested_tree") }
    refute_nil proof, "une étape lit la preuve de l'arbre"
    refute_nil first_deploy
    assert_operator proof, :<, first_deploy
    refute_nil steps[proof]["if"]
    assert_includes steps[proof]["if"].to_s, "github.ref != 'refs/heads/Develop'"
    failing = steps.each_with_index.select { |step, i| i > proof && i < first_deploy && step["run"].to_s.include?("exit 1") }
    refute_empty failing, "une étape échoue sans preuve"
    failing.each { |step, _| assert_includes step["if"].to_s, "github.ref != 'refs/heads/Develop'" }
    assert_includes failing.map { |step, _| step["if"].to_s }.join, "steps.#{steps[proof]['id']}.outputs.tested != 'true'"
  end

  def test_a_dry_run_comes_before_the_first_real_call
    runs = steps.select { |step| deploys?(step) }
    calls = ->(step) { step["run"].lines.reject { |line| line.strip.start_with?("#") }.select { |line| line.include?("deployer.py") } }
    real = runs.index { |step| calls.(step).any? { |line| !line.include?("--dry-run") } }
    dry = runs.index { |step| calls.(step).any? { |line| line.include?("--dry-run") } }

    refute_nil real
    refute_nil dry
    assert_operator dry, :<, real
    refute calls.(runs[dry]).any? { |line| !line.include?("--dry-run") }, "le dry-run n'envoie rien"
  end

  # Every value reaches the shell through env: no expression at all inside a run.
  def test_no_run_interpolates_an_expression
    steps.each do |step|
      refute_includes step["run"].to_s, "${{", step["name"] || step["id"]
    end
  end

  def test_secrets_reach_the_deployer_steps_only
    refute_match SECRET, workflow.fetch("env", {}).to_s, "aucun secret au niveau du workflow"
    refute_match SECRET, job.fetch("env", {}).to_s, "aucun secret au niveau du job"
    refute_match SECRET, (job.reject { |key, _| key == "steps" }.to_s)
    steps.each do |step|
      carries = step.fetch("env", {}).values.any? { |value| value.to_s.match?(SECRET) }
      assert_equal deploys?(step), carries, "secrets seulement dans les étapes qui appellent deployer.py : #{step['name'] || step['id']}"
      refute_match SECRET, step.reject { |key, _| key == "env" }.to_s
    end
  end

  def test_the_job_has_a_timeout_of_100_minutes_at_most
    assert job["timeout-minutes"].to_i.between?(1, 100), "timeout-minutes <= 100"
  end
end
