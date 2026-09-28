# Run using bin/ci — locally and on GitHub (.github/workflows/ci.yml runs this very file).
# One list of steps, one place: bin/ci and the GitHub workflow never diverge (feuille-de-route §2, garde-fou n° 4).
# Order: cheapest and most fundamental first.
#
# The steps are grouped (ADR-0064). Locally, bin/ci plays every group, in this order, as it always did.
# On GitHub, each job plays `CI_GROUP=<group>[,<group>…]`, or one part of a sharded group (`system:2/4`), and the
# jobs run side by side. test/guards/ci_plan_test.rb proves that the jobs of the workflow add up to this whole list.
require_relative "../script/ci/plan"

# The Yarn audit is network-bound (2 min 40 s measured locally) and its result only moves with the JS dependencies.
# GitHub (CI=true) always runs it; locally it runs only when package.json or yarn.lock differ from origin/Develop.
# Fail-safe: if git cannot compare (no origin/Develop), `system` returns false and the audit runs.
yarn_audit = ENV["CI"] || !system("git diff --quiet origin/Develop -- package.json yarn.lock", err: File::NULL)

# `bin/rails test` alone still runs the guards, locally; bin/ci runs them once, in their own steps.
guards_excluded = "test/{system/**/*,dummy/**/*,fixtures/**/*,guards/**/*,domain/domain_purity}_test.rb"

CI_PLAN = CiPlan.define do
  # Golden rules, pure Ruby, no Rails boot (CLAUDE.md, conventions.md §5 and §7, ADR-0024, ADR-0064).
  group "lint" do
    step "Guard: Domain purity", "ruby -Itest test/domain/domain_purity_test.rb"
    step "Guard: HITL headers, no :nocov:, worker in Puma", "ruby -Itest test/guards/repository_rules_test.rb"
    step "Guard: CI groups add up to bin/ci", "ruby -Itest test/guards/ci_plan_test.rb"

    step "Style: Ruby", "bin/rubocop"
  end

  group "security" do
    step "Security: Gem audit", "bin/bundler-audit"
    if yarn_audit
      step "Security: Yarn vulnerability audit", "yarn npm audit --all --recursive"
    else
      step "Security: Yarn vulnerability audit (skipped locally: JS dependencies unchanged since Develop)", "true"
    end
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  end

  group "unit", db: true do
    # Full suite: SimpleCov fails the step below 100 % lines or branches (ADR-0024). Never split: the threshold
    # measures the whole suite, and this group is not the longest one (docs/chantiers/ci-rapide/memo.md).
    # The two guards above already ran: the suite leaves them out here (Rails' default exclusion, plus the guards).
    step "Tests: Rails (coverage 100 % lines and branches)",
         "env DEFAULT_TEST_EXCLUDE='#{guards_excluded}' bin/rails test"
  end

  # Real browser, never rack_test (configuration.md §4.3). Partial run: no threshold (§4.1).
  # -v prints each test's duration: script/ci/record_timings rebuilds the timings of the split from any log.
  # A part names its files, and `bin/rails test <files>` skips test:prepare (the asset build) and runs fewer than
  # 50 tests in a single process: the part builds the assets itself and asks for one worker per CPU.
  sharded "system", files: CiPlan.files("test/system/**/*_test.rb") do |files, part|
    if part
      step "Tests: System (headless Chrome) #{part}", "bin/check-chrome && bin/rails test:prepare && " \
           "env COVERAGE=0 PARALLEL_WORKERS=$(nproc) bin/rails test #{files.join(' ')} -v"
    else
      step "Tests: System (headless Chrome)", "bin/check-chrome && env COVERAGE=0 bin/rails test:system -v"
    end
  end

  group "seeds", db: true do
    # The seeds are then removed: single-process runs (system tests, pre-commit) share this database.
    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant && env RAILS_ENV=test bin/rails db:truncate_all"
  end

  # ADR-0039 : bulk imports under 2 minutes. Skipped by `bin/rails test` without PERF.
  sharded "perf", files: CiPlan.files("test/performance/**/*_test.rb") do |files, part|
    step [ "Tests: Import performance", part ].compact.join(" "), "env PERF=1 COVERAGE=0 bin/rails test #{files.join(' ')} -v"
  end

  # ADR-0051 : gzip ceilings, on freshly compiled assets.
  group "assets" do
    step "Assets: Budget", "yarn build && yarn build:css && bin/check-asset-budget"
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
