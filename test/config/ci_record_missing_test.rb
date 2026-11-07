require "minitest/autorun"
require_relative "../../script/ci/record_missing"

# bin/ci-quiet records the duration of the system files that have none (chantier ci-durees-enregistrees).
class CiRecordMissingTest < Minitest::Test
  FILES = %w[test/system/new_test.rb].freeze

  def test_nothing_is_played_when_every_file_has_a_duration
    played = false
    result = RecordMissing.call([], runner: ->(_) { played = true }, recorder: ->(_) { true })

    refute played
    refute result.recorded
    assert_nil RecordMissing.message(result)
  end

  def test_a_green_run_is_passed_to_the_recorder
    seen = nil
    result = RecordMissing.call(FILES, runner: ->(files) { [ "log of #{files.first}", true ] }, recorder: ->(log) { seen = log; true })

    assert result.recorded
    assert_equal "log of test/system/new_test.rb", seen
    assert_match(/test_timings\.yml est modifié, à commiter avec le lot, puis relancer bin\/ci-quiet/, RecordMissing.message(result))
  end

  def test_a_red_run_records_nothing_and_says_why
    recorded = false
    result = RecordMissing.call(FILES, runner: ->(_) { [ "boom", false ] }, recorder: ->(_) { recorded = true })

    refute recorded
    refute result.recorded
    assert_match(/rouges/, RecordMissing.message(result))
  end

  def test_a_log_without_duration_is_reported_not_swallowed
    result = RecordMissing.call(FILES, runner: ->(_) { [ "", true ] }, recorder: ->(_) { false })

    refute result.recorded
    assert_match(/aucune durée lue/, RecordMissing.message(result))
  end

  def test_the_command_the_guard_suggests_does_not_measure_coverage
    assert_match(/\Aenv COVERAGE=0 bin\/rails test a b -v 2>&1 \| script\/ci\/record_timings\z/, SystemBudget.new(files: [], timings: {}, base_timings: {}, touched: []).record_command(%w[a b]))
  end
end
