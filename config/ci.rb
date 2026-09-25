# Run using bin/ci — locally and on GitHub (.github/workflows/ci.yml runs this very file).
# One list of steps, one place: bin/ci and the GitHub workflow never diverge.
# Order: cheapest and most fundamental first (feuille-de-route §2, garde-fou n° 4).

CI.run do
  step "Setup", "bin/setup --skip-server"

  # Golden rules, pure Ruby, no Rails boot (CLAUDE.md, conventions.md §5 and §7, ADR-0024).
  step "Guard: Domain purity", "ruby -Itest test/domain/domain_purity_test.rb"
  step "Guard: HITL headers, no :nocov:, worker in Puma", "ruby -Itest test/guards/repository_rules_test.rb"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Yarn vulnerability audit", "yarn npm audit --all --recursive"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # Full suite: SimpleCov fails the step below 100 % lines or branches (ADR-0024).
  step "Tests: Rails (coverage 100 % lines and branches)", "bin/rails test"

  # Real browser, never rack_test (configuration.md §4.3). Partial run: no threshold (§4.1).
  step "Tests: System (headless Chrome)", "bin/check-chrome && env COVERAGE=0 bin/rails test:system"

  # The seeds are then removed: single-process runs (system tests, pre-commit) share this database.
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant && env RAILS_ENV=test bin/rails db:truncate_all"

  # ADR-0039 : bulk imports under 2 minutes. Skipped by `bin/rails test` without PERF.
  step "Tests: Import performance", "env PERF=1 COVERAGE=0 bin/rails test test/performance"

  # ADR-0051 : gzip ceilings, on freshly compiled assets.
  step "Assets: Budget", "yarn build && yarn build:css && bin/check-asset-budget"
end
