# Records the duration of the system test files that have none in script/ci/test_timings.yml, for bin/ci-quiet
# (chantier ci-durees-enregistrees): a new system file no longer turns the budget guard red for want of a number.
# The files are played once, verbose and without coverage (a threshold is a full-suite measure), and the log goes to
# script/ci/record_timings. A red run records nothing: its fast failures would weigh less than the test costs, and
# the system step reports the failure. The budget itself is checked on the measured duration by the guard.
require "open3"
require_relative "system_budget"

module RecordMissing
  Result = Struct.new(:files, :recorded, :reason, keyword_init: true)

  # runner: files -> [log, green]; recorder: log -> green. Both are injected so that the rules are testable.
  def self.call(files, runner:, recorder:)
    return Result.new(files: [], recorded: false) if files.empty?

    log, green = runner.call(files)
    return Result.new(files:, recorded: false, reason: "les tests sont rouges : durée non enregistrée") unless green
    return Result.new(files:, recorded: false, reason: "aucune durée lue dans le journal") unless recorder.call(log)

    Result.new(files:, recorded: true)
  end

  def self.runner
    lambda do |files|
      out, status = Open3.capture2e({ "COVERAGE" => "0", "PARALLEL_WORKERS" => "2" }, "bin/rails", "test", *files, "-v")
      [ out, status.success? ]
    end
  end

  def self.recorder
    lambda do |log|
      _, status = Open3.capture2e("script/ci/record_timings", stdin_data: log)
      status.success?
    end
  end

  def self.message(result)
    return nil if result.files.empty?

    list = result.files.join(", ")
    if result.recorded
      "⏱  Durée enregistrée pour #{list} : script/ci/test_timings.yml est modifié, à commiter avec le lot, " \
        "puis relancer bin/ci-quiet (rien d'autre n'a été joué)."
    else
      "⚠️  Durée non enregistrée pour #{list} (#{result.reason}) ; la garde du budget reste rouge."
    end
  end
end
