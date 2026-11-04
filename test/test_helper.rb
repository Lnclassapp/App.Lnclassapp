# Coverage: 100 %, lines AND branches, blocking (ADR-0024).
# COVERAGE=0 disables the measurement on partial runs (pre-commit, one file):
# a threshold is a full-suite measure, applying it to a subset is a guaranteed
# false negative (docs/guide/configuration.md §4.1).
# COVERAGE_PART=k/n: one part of the unit suite on GitHub (ADR-0064 §1, amended). It measures under its own name and
# checks nothing; the « coverage » job merges the parts and checks the threshold on the whole suite.
unless ENV["COVERAGE"] == "0"
  require_relative "coverage_profile"

  SimpleCov.start "lnclass" do
    if (part = ENV["COVERAGE_PART"].to_s.strip).empty?
      minimum_coverage LnclassCoverage::MINIMUM
    else
      command_name "unit #{part}"
    end
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Every helper of test/support includes itself (plan boucle-pedagogique §0a.5): a lot adds
# its own without touching this file. Test files living there are run, never required.
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.reject { it.end_with?("_test.rb") }.each { require it }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # rate_limit counts in the cache (ADR-0050): no count may leak from one test to the next.
    setup { Rails.cache.clear }

    # Add more helper methods to be used by all tests here...
  end
end
