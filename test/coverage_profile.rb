# The coverage settings, shared by the test run (test/test_helper.rb) and by the merge of the parts of the unit
# suite on GitHub (script/ci/coverage_collate): the threshold of ADR-0024 is the same measure on both roads.
require "simplecov"

SimpleCov.profiles.define "lnclass" do
  load_profile "rails"
  enable_coverage :branch

  # Inherited from the "rails" profile, written out on purpose: every figure
  # depends on it. A file no test loads counts as 0 % instead of vanishing.
  # `cover` replaces the deprecated `track_files` (configuration.md §4.2).
  cover "{app,lib}/**/*.rb"

  # Rails runs tests in forked workers: each fork writes its own result,
  # merged by the parent before the threshold is checked.
  merge_subprocesses true

  group "Domaine",        "app/domain"
  group "Infrastructure", [ "app/infrastructure", "app/models", "app/jobs", "app/mailers" ]
  group "Delivery",       [ "app/controllers", "app/helpers" ]
end

module LnclassCoverage
  # ADR-0024: 100 %, lines AND branches, blocking. Checked on the whole suite only.
  MINIMUM = { line: 100, branch: 100 }.freeze
end
