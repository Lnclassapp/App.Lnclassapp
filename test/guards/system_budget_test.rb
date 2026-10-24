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
                                   "budget #{subject.budget} s pour ce chantier (ADR-0069 §9) : des tests redescendent " \
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
  # Amendement du 2026-10-03 : le porteur accorde 20 s au blog ; ses deux fichiers seuls ont ce budget, pas un chantier qui
  # les touche avec d'autres.
  def test_the_blog_has_twenty_seconds_and_no_other_change_borrows_them
    blog = SystemBudget::GRANTS.fetch("blog")[:files]
    reading, management = blog

    assert_equal 20.0, SystemBudget::GRANTS.fetch("blog")[:budget]
    assert budget(timings: { reading => 2.7, management => 15.5 }, touched: blog).within_budget?, "18,2 s pour le blog"
    refute budget(timings: { reading => 4.6, management => 15.5 }, touched: blog).within_budget?, "20,1 s : au-delà"
    mixed = budget(timings: { reading => 2.7, management => 15.5, "other" => 0.5 }, touched: blog + %w[other])

    assert_equal 15.0, mixed.budget
    refute mixed.within_budget?
  end

  # Amendement du 2026-10-24 : 50 s pour les seuls fichiers système de mvp-teacher-student.
  def test_mvp_teacher_student_has_fifty_seconds_for_its_own_files_only
    signup, page = %w[test/system/identity/student_signup_steps_test.rb test/system/classroom/classroom_page_test.rb]

    assert_equal 23, SystemBudget::GRANTS.fetch("mvp-teacher-student")[:files].size
    assert_includes SystemBudget::GRANTS.fetch("mvp-teacher-student")[:files], signup
    assert budget(timings: { signup => 30.0, page => 20.0 }, touched: [ signup, page ]).within_budget?, "50 s : accepté"
    refute budget(timings: { signup => 30.0, page => 20.1 }, touched: [ signup, page ]).within_budget?, "50,1 s : au-delà"
    mixed = budget(timings: { signup => 10.0, "other" => 0.5 }, touched: [ signup, "other" ])

    assert_equal 15.0, mixed.budget, "un autre fichier qui grandit avec eux ramène à 15 s"
  end
end
