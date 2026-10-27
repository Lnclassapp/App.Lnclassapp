# Run using bin/ci — locally and on GitHub (.github/workflows/ci.yml runs this very file).
# One list of steps, one place: bin/ci and the GitHub workflow never diverge (feuille-de-route §2, garde-fou n° 4).
# Order: cheapest and most fundamental first.
#
# The steps are grouped (ADR-0064). bin/ci plays every group, in this order, locally; GitHub plays them in two
# kinds of jobs side by side, « unit » (every group but system) and three parts of « system » (ADR-0069 §9: the
# minutes are counted per job, the clock stays under ten minutes). `CI_GROUP=<group>[,<group>…]` or a part of a sharded group
# (`system:2/4`) plays a subset.
require_relative "../script/ci/plan"
require_relative "../script/ci/scope"

# The Yarn audit is network-bound (2 min 40 s measured locally) and its result only moves with the JS dependencies.
# GitHub (CI=true) always runs it; locally it runs only when package.json or yarn.lock differ from origin/Develop.
# Fail-safe: if git cannot compare (no origin/Develop), `system` returns false and the audit runs.
yarn_audit = ENV["CI"] || !system("git diff --quiet origin/Develop -- package.json yarn.lock", err: File::NULL)

# The paths that can move the import performance (ADR-0039): a wide list, better to play the tests for nothing than miss one.
PERF_PATHS = %w[
  app/domain app/infrastructure app/jobs db lib Gemfile.lock config/database.yml config/ci.rb
  script/ci test/performance test/test_helper.rb
].freeze
# Left out of the comparison: the recorded durations of the split move on almost every pull request
# (script/ci/record_timings) and change nothing for a local run, which never splits.
PERF_IGNORED = %w[script/ci/test_timings.yml].freeze

# `bin/rails test` alone still runs the guards, locally; bin/ci runs them once, in their own steps.
guards_excluded = "test/{system/**/*,dummy/**/*,fixtures/**/*,guards/**/*,domain/domain_purity}_test.rb"

CI_PLAN = CiPlan.define do
  # Golden rules, pure Ruby, no Rails boot (CLAUDE.md, conventions.md §5 and §7, ADR-0024, ADR-0064).
  group "lint" do
    step "Guard: Domain purity", "ruby -Itest test/domain/domain_purity_test.rb"
    step "Guard: HITL headers, no :nocov:, worker in Puma", "ruby -Itest test/guards/repository_rules_test.rb"
    step "Guard: CI groups add up to bin/ci", "ruby -Itest test/guards/ci_plan_test.rb"
    step "Guard: System suite budget (15 s per chantier)", "ruby -Itest test/guards/system_budget_test.rb"
    step "Guard: Android shell (minSdk 28, variants, no signing key)", "ruby -Itest test/guards/android_project_test.rb"
    # conventions.md §7: the delivery is what origin/main lacks. A GitHub checkout has no origin/main: it is fetched
    # (depth 1) when missing, never otherwise, so a full local clone does not turn shallow. Without it, every migration is checked.
    step "Guard: Migrations in two steps",
         "{ git rev-parse -q --verify refs/remotes/origin/main >/dev/null || " \
         "git fetch -q --depth=1 origin main:refs/remotes/origin/main; }; ruby -Itest test/guards/migration_rules_test.rb"
    # conventions.md §2: the decision indexes are up to date, no number is taken twice, and no XXXX- decision reaches
    # Develop, Staging or main (GITHUB_BASE_REF names the target of a pull request).
    step "Guard: Decision index (numbers set at merge)", "script/docs/build_index --check"

    step "Style: Ruby", "bin/rubocop", inputs: :ruby
  end

  group "security" do
    step "Security: Gem audit", "bin/bundler-audit", inputs: :gems
    if yarn_audit
      step "Security: Yarn vulnerability audit", "yarn npm audit --all --recursive", inputs: :yarn
    else
      step "Security: Yarn vulnerability audit (skipped locally: JS dependencies unchanged since Develop)", "true"
    end
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error", inputs: :brakeman
  end

  group "unit", db: true do
    # Full suite: SimpleCov fails the step below 100 % lines or branches (ADR-0024). Never split: the threshold
    # measures the whole suite, and this group is not the longest one (docs/chantiers/ci-rapide/memo.md).
    # The two guards above already ran: the suite leaves them out here (Rails' default exclusion, plus the guards).
    step "Tests: Rails (coverage 100 % lines and branches)",
         "env DEFAULT_TEST_EXCLUDE='#{guards_excluded}' bin/rails test", inputs: :unit
  end

  # Real browser, never rack_test (configuration.md §4.3). Partial run: no threshold (§4.1).
  # -v prints each test's duration: script/ci/record_timings rebuilds the timings of the split from any log.
  # A part names its files, and `bin/rails test <files>` skips test:prepare (the asset build) and runs fewer than
  # 50 tests in a single process: the part builds the assets itself and asks for one worker per CPU.
  sharded "system", files: CiPlan.files("test/system/**/*_test.rb") do |files, part|
    if part
      step "Tests: System (headless Chrome) #{part}", "bin/check-chrome && bin/rails test:prepare && " \
           "env COVERAGE=0 PARALLEL_WORKERS=$(nproc) bin/rails test #{files.join(' ')} -v", inputs: :system
    else
      step "Tests: System (headless Chrome)", "bin/check-chrome && env COVERAGE=0 bin/rails test:system -v", inputs: :system
    end
  end

  group "seeds", db: true do
    # The seeds are then removed: single-process runs (system tests, pre-commit) share this database.
    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant && env RAILS_ENV=test bin/rails db:truncate_all", inputs: :seeds
  end

  # ADR-0039 : bulk imports under 2 minutes. Skipped by `bin/rails test` without PERF.
  # ADR-0067 : the screen budgets (*_budget_test.rb) seed 312 000 sessions, ≈ 2 min 30 : they run before each
  # recette and in the chantiers that touch those screens, never in bin/ci.
  # Locally, the step plays only when the tree differs from origin/Develop on PERF_PATHS (the condition lives in the
  # shell command, so the title and the files stay the same for the guards and for GitHub). It plays too on GitHub
  # (GITHUB_ACTIONS: bin/ci sets CI=true on every machine, so CI never told a local run apart), and when git cannot
  # compare (fail-safe, as for the Yarn audit): `git diff --name-only` then fails.
  # When the difference is only in performance test files (a test changed, nothing it measures), only the changed
  # files of this list play (chantier ci-rejeu-cible); a screen budget alone plays nothing, as before. The promotion into Staging replays it (ADR-0069 §9).
  perf_files = CiPlan.files("test/performance/**/*_test.rb") - CiPlan.files("test/performance/**/*_budget_test.rb")
  sharded "perf", files: perf_files do |files, part|
    play = ->(list) { "env PERF=1 COVERAGE=0 bin/rails test #{list} -v" }
    skip = "echo 'Import performance skipped locally: nothing changed since origin/Develop in #{PERF_PATHS.join(' ')}'"
    ignored = PERF_IGNORED.map { "':(exclude)#{it}'" }.join(" ")
    only = "only=''; for f in #{files.join(' ')}; do printf '%s\\n' \"$changed\" | grep -qxF \"$f\" && only=\"$only $f\"; done; " \
           "if [ -n \"$only\" ]; then echo \"Import performance: only the changed tests:$only\"; #{play.('$only')}; else #{skip}; fi"
    step [ "Tests: Import performance", part ].compact.join(" "),
         "if [ -n \"${GITHUB_ACTIONS:-}\" ] || ! changed=$(git diff --name-only origin/Develop -- #{PERF_PATHS.join(' ')} #{ignored} 2>/dev/null); " \
         "then #{play.(files.join(' '))}; elif [ -z \"$changed\" ]; then #{skip}; " \
         "elif ! printf '%s\\n' \"$changed\" | grep -qvE '^test/performance/.+_test\\.rb$'; then #{only}; " \
         "else #{play.(files.join(' '))}; fi",
         inputs: CiScope::Inputs.new(only: PERF_PATHS, except: PERF_IGNORED)
  end

  # ADR-0051 : gzip ceilings, on freshly compiled assets.
  group "assets" do
    step "Assets: Budget", "yarn build && yarn build:css && bin/check-asset-budget", inputs: :assets
  end
end

# bin/ci defines CI; the guard test loads this file for CI_PLAN alone.
if defined?(CI)
  begin
    steps = CI_PLAN.steps_for(ENV["CI_GROUP"])
  rescue CiPlan::SelectionError => error
    abort "❌ #{error.message}"
  end

  CI.run(*("Continuous Integration (#{ENV['CI_GROUP']})" if ENV["CI_GROUP"].to_s.strip != "")) do
    steps.each { step it.title, it.command }
  end
end
