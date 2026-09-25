# Coverage: 100 %, lines AND branches, blocking (ADR-0024).
# COVERAGE=0 disables the measurement on partial runs (pre-commit, one file):
# a threshold is a full-suite measure, applying it to a subset is a guaranteed
# false negative (docs/guide/configuration.md §4.1).
unless ENV["COVERAGE"] == "0"
  require "simplecov"

  SimpleCov.start "rails" do
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

    minimum_coverage line: 100, branch: 100
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
