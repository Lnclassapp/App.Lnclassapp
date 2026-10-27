# Pure Ruby, no Rails boot: bin/ci is one list of steps, played whole by the jobs of the GitHub workflow
# (feuille-de-route §2, garde-fou n° 4; ADR-0064, ADR-0069). The rules that keep the GitHub minutes within the quota
# and every job under five minutes (ADR-0107) fail here, in the lint group, before any test runs.
require "minitest/autorun"
require "yaml"
require "json"
require "fileutils"
require "open3"
require "tmpdir"
load File.expand_path("../../config/ci.rb", __dir__) unless defined?(CI_PLAN)

class CiPlanTest < Minitest::Test
  GITHUB = File.expand_path("../../.github", __dir__)
  WORKFLOW = File.join(GITHUB, "workflows/ci.yml")
  # ADR-0069 §9, ADR-0107 : the jobs that play bin/ci, side by side; « unit » is a matrix of group lists drawn by
  # « plan », « system » a matrix of SYSTEM_PARTS parts. No job runs longer than JOB_MINUTES (the owner's ceiling).
  TEST_JOBS = %w[unit system].freeze
  SYSTEM_PARTS = 6
  PERF_PARTS = 2
  JOB_MINUTES = 5

  def workflow = YAML.safe_load_file(WORKFLOW, aliases: true)

  def jobs = workflow.fetch("jobs")

  # YAML reads the key `on` as true.
  def triggers = workflow.fetch(true)

  def steps(job) = jobs.fetch(job).fetch("steps")

  def bin_ci(job) = steps(job).find { it["run"] == "bin/ci" }

  def draw_script = steps("plan").find { it["id"] == "draw" }["run"]

  # The parts of « unit » the draw writes for a full run (&&) and for a partial one (||).
  def unit_parts(operator) = JSON.parse(draw_script[/#{Regexp.escape(operator)} unit='(\[[^']*\])'/, 1])

  # The titles bin/ci plays for a selection, Setup left out.
  def titles(selection) = CI_PLAN.steps_for(selection).drop(1).map(&:title)

  # ADR-0069 §9 : « plan » decides, the parts of « unit » and « system » play bin/ci side by side, « ci » is the one
  # status the branches wait for. The only matrices are the parts of « unit » and « system ».
  def test_plan_decides_the_test_jobs_play_bin_ci_and_ci_gives_the_verdict
    assert_equal %w[plan unit system ci], jobs.keys
    jobs.each do |name, job|
      assert_equal name, job["name"].to_s.split.first, "le job « #{name} » porte son nom"
      assert_nil job["strategy"], "pas de matrice : #{name}" unless TEST_JOBS.include?(name)
    end
    TEST_JOBS.each do |name|
      assert_equal "plan", jobs.dig(name, "needs")
      assert_equal 1, steps(name).count { it["run"] == "bin/ci" }, "« #{name} » lance bin/ci une fois"
    end
    assert_equal %w[plan unit system], jobs.dig("ci", "needs")
    %w[plan ci].each { |name| assert_nil bin_ci(name), "« #{name} » ne joue pas bin/ci" }
  end

  # ADR-0069 §9 : the two jobs add up to bin/ci: on a full run (promotion, drawn pull request) every group once,
  # nothing twice; any other run that replays the suite leaves out the import performance tests only (ADR-0039),
  # checked again at the promotion. The unit suite is one part of its own: its coverage measures the whole suite.
  def test_the_two_jobs_add_up_to_bin_ci_and_a_partial_run_leaves_out_the_performance_tests_only
    assert_equal "${{ fromJSON(needs.plan.outputs.unit) }}", jobs.dig("unit", "strategy", "matrix", "groups")
    assert_equal "${{ matrix.groups }}", bin_ci("unit").dig("env", "CI_GROUP")
    assert_equal (1..SYSTEM_PARTS).to_a, jobs.dig("system", "strategy", "matrix", "part")
    assert_equal "system:${{ matrix.part }}/#{SYSTEM_PARTS}", bin_ci("system").dig("env", "CI_GROUP")
    split = CI_PLAN.split("system", SYSTEM_PARTS)
    assert_equal CiPlan.files("test/system/**/*_test.rb").sort, split.flatten.sort, "chaque fichier système dans une part, une seule"
    assert_includes unit_parts("&&"), "unit", "la suite unitaire, seule dans sa part"
    assert_includes unit_parts("||"), "unit"
    (1..PERF_PARTS).each { assert_includes unit_parts("&&"), "perf:#{it}/#{PERF_PARTS}" }
    assert_equal CI_PLAN.steps_for("perf").last.command.scan(%r{test/performance/\S+_test\.rb}).uniq.sort, CI_PLAN.split("perf", PERF_PARTS).flatten.sort
    full = unit_parts("&&").join(",")
    partial = unit_parts("||").join(",")
    groups = ->(selection) { selection.split(",").map { it.sub(/:.*/, "") }.uniq }
    whole = ->(selection) { titles(selection).map { it.sub(%r{ \d+/\d+\z}, "") }.uniq }

    assert_equal CI_PLAN.groups.keys.sort, (groups.(full) + [ "system" ]).sort, "un run complet joue chaque groupe une fois"
    assert_equal CI_PLAN.groups.keys.sort - [ "perf" ], (groups.(partial) + [ "system" ]).sort, "le run partiel laisse « perf »"
    assert_equal titles(nil).sort, (whole.(full) + titles("system")).sort
    assert_equal (titles(nil) - titles("perf")).sort, (titles(partial) + titles("system")).sort
  end

  # ADR-0069 : 45 % of the runs were pushes that merged a tree their pull request had already tested.
  # Pull requests only, and a draft waits until it is ready for review: « plan » is skipped, so is everything after.
  def test_the_workflow_runs_on_ready_pull_requests_only
    assert_equal [ "pull_request" ], triggers.keys
    assert_includes triggers.dig("pull_request", "types"), "ready_for_review"
    # Amendment of 2026-10-04: and only while the repository variable CI_ENABLED is « true » (the owner's switch).
    # ADR-0107 : and only into Staging and main, once per train; a pull request into Develop proves its change locally.
    assert_equal "${{ !github.event.pull_request.draft && vars.CI_ENABLED == 'true' && " \
                 "(github.base_ref == 'Staging' || github.base_ref == 'main') }}", jobs.dig("plan", "if")
    TEST_JOBS.each { |name| assert_equal "needs.plan.outputs.code == 'true'", jobs.dig(name, "if"), name }
    assert_equal "${{ !cancelled() && needs.plan.result != 'skipped' }}", jobs.dig("ci", "if")
  end

  # ADR-0107 : the owner's ceiling, five minutes, holds for every job: a part that grows past it turns the run red.
  def test_no_job_runs_longer_than_five_minutes
    jobs.each { |name, job| assert job["timeout-minutes"].to_i.between?(1, JOB_MINUTES), "#{name} : timeout-minutes ≤ #{JOB_MINUTES}" }
  end

  # ADR-0069 : a tree that already got a green « ci » is not replayed; only a run whose two jobs played the checks
  # and are green proves it, from the verdict.
  def test_a_tested_tree_is_not_replayed_and_only_two_green_jobs_publish_the_proof
    plan = steps("plan")
    proof = plan.find { it["id"] == "proof" }
    assert_equal "script/ci/tested_tree", proof["run"]
    assert_equal "steps.proof.outputs.tested != 'true'", plan.find { it["id"] == "changes" }["if"]
    assert_equal "${{ steps.changes.outputs.code }}", jobs.dig("plan", "outputs", "code")

    verdict = steps("ci").find { it["id"] == "verdict" }["run"]
    assert_match(/\[ "\$UNIT" = success \] && \[ "\$SYSTEM" = success \]/, verdict, "la preuve attend les deux jobs verts")
    publish = steps("ci").find { it.dig("with", "name").to_s.start_with?("ci-tree-") }
    assert_equal "steps.verdict.outputs.proof == 'true'", publish["if"]
    assert_equal "ci-tree-${{ needs.plan.outputs.tree }}", publish.dig("with", "name")
    TEST_JOBS.each do |name|
      refute steps(name).any? { it.dig("with", "name").to_s.start_with?("ci-tree-") }, "« #{name} » ne publie pas de preuve"
    end
  end

  # ADR-0069 §8 : the draw runs before the proof and can skip it: a promotion into Staging always replays the suite,
  # and one pull request into Develop in five, drawn with a secret nobody running the pull request can read.
  def test_the_draw_comes_first_and_staging_always_replays_the_suite
    plan = steps("plan")
    draw = plan.index { it["id"] == "draw" }
    proof = plan.index { it["id"] == "proof" }

    assert draw && proof && draw < proof, "le tirage passe avant la preuve"
    assert_equal "steps.draw.outputs.full != 'true'", plan[proof]["if"]
    assert_match(/"\$BASE" = "Staging" \]/, draw_script, "une promotion vers Staging rejoue toujours la suite")
    assert_match(/% 5 \)\) -eq 0/, draw_script, "une PR sur cinq")
    assert_equal "${{ secrets.CI_DRAW_SALT }}", plan[draw].dig("env", "SALT")
  end

  # ADR-0069 §8 : a cloud session's proof counts for a pull request into Develop only; never for main.
  def test_a_cloud_proof_counts_for_develop_only
    proof = steps("plan").find { it["id"] == "proof" }

    assert_equal "${{ github.base_ref == 'Develop' }}", proof.dig("env", "LOCAL_PROOF")
  end

  # ADR-0067 : the screen budgets seed 312 000 sessions; they run before each recette, never in bin/ci.
  def test_the_screen_budgets_stay_out_of_bin_ci
    played = CI_PLAN.steps_for(nil).map(&:command).join(" ")

    refute_empty CiPlan.files("test/performance/**/*_budget_test.rb")
    CiPlan.files("test/performance/**/*_budget_test.rb").each { refute_includes played, it }
    assert_includes played, "test/performance/catalog/import_course_tree_performance_test.rb"
  end

  # The import performance (≈ 1 min 30) plays locally only when the tree moved on the paths that can change it, always
  # on GitHub, and whenever git cannot compare. The condition is the shell one of the step, played here in a
  # throwaway repository whose `bin/rails` is replaced by `echo` : the step prints « test » when it plays.
  def test_the_import_performance_plays_under_ci_on_a_difference_or_when_git_cannot_compare
    perf = CI_PLAN.steps_for("perf").last.command

    %w[app/domain app/infrastructure app/jobs db test/performance].each do |path|
      assert_includes PERF_PATHS, path
    end
    CiPlan.files("test/performance/**/*_test.rb").grep_v(/_budget_test/).each { assert_includes perf, it }

    in_repository do |repo|
      assert_skipped run_perf(perf, repo), "un arbre identique à origin/Develop saute la perf"
      FileUtils.mkdir_p(File.join(repo, "app/views"))
      File.write(File.join(repo, "app/views/page.erb"), "x")
      git(repo, "add", "-A")
      assert_skipped run_perf(perf, repo), "un chemin hors de la liste la saute encore"
      assert_played run_perf(perf, repo, "GITHUB_ACTIONS" => "true"), "sur GitHub, elle joue"
      assert_skipped run_perf(perf, repo, "CI" => "true"), "bin/ci pose CI=true partout : CI ne distingue pas GitHub"

      FileUtils.mkdir_p(File.join(repo, "script/ci"))
      File.write(File.join(repo, "script/ci/test_timings.yml"), "x")
      git(repo, "add", "-A")
      assert_skipped run_perf(perf, repo), "les durées enregistrées du découpage ne la jouent pas"
      File.write(File.join(repo, "script/ci/plan.rb"), "x")
      git(repo, "add", "-A")
      assert_played run_perf(perf, repo), "un autre fichier de script/ci la joue"
      git(repo, "rm", "-q", "-f", "--cached", "script/ci/plan.rb", "script/ci/test_timings.yml")
      FileUtils.rm_rf(File.join(repo, "script"))

      %w[app/domain app/infrastructure app/jobs db test/performance].each do |path|
        FileUtils.mkdir_p(File.join(repo, path))
        File.write(File.join(repo, path, "touched.rb"), "x")
        git(repo, "add", "-A")
        assert_played run_perf(perf, repo), "un écart sur #{path} la joue"
        git(repo, "rm", "-q", "-f", "--cached", File.join(path, "touched.rb"))
        FileUtils.rm_f(File.join(repo, path, "touched.rb"))
      end

      # Chantier ci-rejeu-cible: a change to performance tests alone plays those tests alone.
      target, other = CiPlan.files("test/performance/**/*_test.rb").grep_v(/_budget_test/).sort.first(2)
      FileUtils.mkdir_p(File.join(repo, File.dirname(target)))
      File.write(File.join(repo, target), "x")
      git(repo, "add", "-A")
      output = run_perf(perf, repo)
      assert_match(/^test #{Regexp.escape(target)} -v$/, output, "seul le test de perf changé joue")
      refute_includes output, other
      FileUtils.mkdir_p(File.join(repo, "app/domain"))
      File.write(File.join(repo, "app/domain/touched.rb"), "x")
      git(repo, "add", "-A")
      assert_includes run_perf(perf, repo), other, "un test de perf et le code qu'il mesure : tout joue"
      git(repo, "rm", "-q", "-f", "--cached", "app/domain/touched.rb", target)
      FileUtils.rm_f([ File.join(repo, "app/domain/touched.rb"), File.join(repo, target) ])
      budget = CiPlan.files("test/performance/**/*_budget_test.rb").first
      FileUtils.mkdir_p(File.join(repo, File.dirname(budget)))
      File.write(File.join(repo, budget), "x")
      git(repo, "add", "-A")
      assert_skipped run_perf(perf, repo), "un budget d'écran seul ne joue rien : il ne tourne jamais dans bin/ci"
      git(repo, "rm", "-q", "-f", "--cached", budget)

      git(repo, "update-ref", "-d", "refs/remotes/origin/Develop")
      assert_played run_perf(perf, repo), "sans origin/Develop, elle joue (fail-safe)"
    end
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

  # ADR-0069 §9 : the PostgreSQL of the runner image, started before bin/ci in each test job; no service container
  # to pull and start, anywhere.
  def test_postgresql_comes_from_the_image_and_starts_before_bin_ci
    jobs.each { |name, job| assert_nil job["services"], "aucun conteneur de service : #{name}" }
    TEST_JOBS.each do |name|
      played = steps(name)
      postgres = played.index { it["name"] == "PostgreSQL of the image" }

      assert postgres && postgres < played.index { it["run"] == "bin/ci" }, "PostgreSQL démarre avant bin/ci : #{name}"
      assert_match(/systemctl start postgresql/, played[postgres]["run"])
      assert_match(/pg_isready -h 127\.0\.0\.1/, played[postgres]["run"])
    end
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
    assert_equal "bin/setup --skip-server", CI_PLAN.steps_for(nil).first.command
  end

  def test_a_group_list_keeps_the_order_of_the_full_run
    assert_equal CI_PLAN.steps_for("unit,seeds").map(&:title), CI_PLAN.steps_for("seeds, unit").map(&:title)
  end

  private

  # A git hook (the pre-commit) exports GIT_DIR and GIT_INDEX_FILE: left in place, they would point every command below
  # at the real repository instead of the throwaway one.
  def clean_git_env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }

  def git(repo, *args)
    Open3.capture2e(clean_git_env, "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args)
  end

  # A repository whose HEAD is origin/Develop, with one file under each directory of the performance paths.
  def in_repository
    Dir.mktmpdir do |repo|
      %w[app/domain app/infrastructure app/jobs db lib test/performance].each do |dir|
        FileUtils.mkdir_p(File.join(repo, dir))
        File.write(File.join(repo, dir, "base.rb"), "x")
      end
      git(repo, "init", "-q")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "base")
      git(repo, "update-ref", "refs/remotes/origin/Develop", "HEAD")
      yield repo
    end
  end

  def run_perf(command, repo, env = {})
    Open3.capture2e(clean_git_env.merge("CI" => nil, "GITHUB_ACTIONS" => nil).merge(env), "sh", "-c", command.gsub("bin/rails", "echo"), chdir: repo).first
  end

  def assert_played(output, message) = assert_match(/^test test\//, output, message)

  def assert_skipped(output, message)
    assert_match(/skipped locally/, output, message)
    refute_match(/^test test\//, output, message)
  end
end
