# Pure Ruby, no Rails boot (lint group of bin/ci, pre-commit): the system suite grows by at most 15 s of recorded
# duration per chantier (ADR-0069 §9, owner's decision of 2026-10-03), and every system test file has a recorded
# duration, else it would weigh nothing. The repository itself is the first case; the rules follow on small sets.
require "minitest/autorun"
require_relative "../../script/ci/system_budget"

class SystemBudgetTest < Minitest::Test
  def budget(timings:, base: {}, touched: [], files: timings.keys)
    SystemBudget.new(files:, timings:, base_timings: base, touched:)
  end

  def test_this_repository_records_every_system_test_and_this_change_stays_within_the_budget
    subject = SystemBudget.from_git

    assert_empty subject.missing, "durée non enregistrée (script/ci/test_timings.yml) : #{subject.record_command(subject.missing)}"
    assert subject.within_budget?, "la suite système grandit de #{subject.growth} s avec #{subject.touched.join(', ')} ; " \
                                   "budget #{SystemBudget::BUDGET} s par chantier (ADR-0069 §9) : des tests redescendent " \
                                   "au niveau contrôleur, ou le porteur relève le budget"
  end

  def test_only_the_touched_files_count_and_a_removed_test_gives_its_seconds_back
    subject = budget(timings: { "a" => 10.0, "b" => 30.0, "n" => 12.0 }, base: { "a" => 10.0, "b" => 9.0, "d" => 4.0 },
                     touched: %w[n d])

    assert_equal 8.0, subject.growth, "n ajoute 12 s, d en rend 4 ; b, réenregistré sans être touché, ne compte pas"
    assert subject.within_budget?
  end

  def test_the_budget_is_fifteen_seconds_per_chantier
    assert_equal 15.0, SystemBudget::BUDGET
    assert budget(timings: { "n" => 15.0 }, touched: %w[n]).within_budget?
    refute budget(timings: { "n" => 15.1 }, touched: %w[n]).within_budget?
    assert budget(timings: { "n" => 20.0 }, base: { "n" => 6.0 }, touched: %w[n]).within_budget?, "un fichier qui grandit compte sa différence"
  end

  def test_a_system_file_without_a_recorded_duration_is_missing_and_weighs_nothing
    subject = budget(timings: { "a" => 1.0 }, files: %w[a new], touched: %w[new])

    assert_equal %w[new], subject.missing
    assert_equal 0.0, subject.growth
    assert_equal "bin/rails test new -v 2>&1 | script/ci/record_timings", subject.record_command(subject.missing)
  end
end
