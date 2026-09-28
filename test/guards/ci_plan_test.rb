# Pure Ruby, no Rails boot: bin/ci is one list of steps, and the GitHub jobs add up to exactly that list
# (feuille-de-route §2, garde-fou n° 4; ADR-0064). A group missing from the workflow, played twice, or a test file
# left out of every part fails here, in the lint group, before any test runs.
require "minitest/autorun"
require "yaml"
load File.expand_path("../../config/ci.rb", __dir__) unless defined?(CI_PLAN)

class CiPlanTest < Minitest::Test
  WORKFLOW = File.expand_path("../../.github/workflows/ci.yml", __dir__)

  # Every CI_GROUP a job of the workflow plays: the literal value, or each entry of its `matrix.group`.
  def workflow_selections
    YAML.safe_load_file(WORKFLOW, aliases: true).fetch("jobs").values.flat_map do |job|
      value = job.dig("env", "CI_GROUP")
      next [] unless value
      next job.dig("strategy", "matrix", "group") if value.include?("matrix.group")

      [ value ]
    end
  end

  def full_run = CI_PLAN.steps_for(nil)

  def without_part(title) = title.sub(%r{ \d+/\d+\z}, "")

  def test_the_workflow_jobs_add_up_to_the_steps_of_a_local_bin_ci
    played = workflow_selections.flat_map { CI_PLAN.steps_for(it).drop(1) }
    expected = full_run.drop(1)

    assert_equal expected.map(&:group).uniq.sort, played.map(&:group).uniq.sort, "un groupe de config/ci.rb n'est joué par aucun job"
    expected.map(&:group).uniq.each do |group|
      whole = expected.select { it.group == group }.map(&:title)
      parts = played.select { it.group == group }.map { without_part(it.title) }.uniq

      assert_equal whole, parts, "le groupe « #{group} » n'est pas joué tel quel par le workflow"
    end
  end

  def test_each_group_is_played_by_exactly_one_job_or_by_all_its_parts_once
    picks = workflow_selections.flat_map { it.split(",") }.map { it.strip.split(":") }
    picks.group_by(&:first).each do |group, entries|
      if entries.size == 1 && entries.first.size == 1
        pass
      else
        counts = entries.map { it.fetch(1) { flunk "« #{group} » joué entier et en parts" } }
        total = counts.first.split("/").last.to_i

        assert_equal (1..total).map { "#{it}/#{total}" }, counts.sort_by(&:to_i), "parts de « #{group} » incomplètes ou en double"
      end
    end
  end

  def test_the_parts_of_a_sharded_group_hold_every_file_once
    workflow_selections.flat_map { it.split(",") }.map(&:strip).grep(%r{:\d+/\d+\z}).group_by { it.split(":").first }.each do |group, tokens|
      parts = tokens.first[%r{/(\d+)\z}, 1].to_i
      split = CI_PLAN.split(group, parts)

      assert_equal CI_PLAN.groups.fetch(group).files, split.flatten.sort, "« #{group} » : un fichier est absent ou joué deux fois"
      assert split.none?(&:empty?), "« #{group} » : une part vide ne teste rien"
    end
  end

  def test_the_split_is_deterministic_and_puts_the_longest_file_alone
    plan = CiPlan.define { sharded("demo", files: %w[a b c d]) { |files, _| step "x", files.join(" ") } }
    timings = { "a" => 10.0, "b" => 4.0, "c" => 3.0, "d" => 2.0 }

    assert_equal [ %w[a], %w[b c d] ], plan.split("demo", 2, timings:)
    assert_equal plan.split("demo", 2, timings:), plan.split("demo", 2, timings: timings.to_a.reverse.to_h)
  end

  def test_a_file_without_timing_weighs_the_median
    plan = CiPlan.define { sharded("demo", files: %w[a b c new]) { |files, _| step "x", files.join(" ") } }

    assert_equal [ %w[a], %w[b c new] ], plan.split("demo", 2, timings: { "a" => 9.0, "b" => 1.0, "c" => 2.0 })
  end

  def test_an_unknown_group_or_part_fails_loudly_instead_of_playing_nothing
    [ "lnit", "system:5/4", "system:0/4", "lint:1/2" ].each do |selection|
      assert_raises(CiPlan::SelectionError, selection) { CI_PLAN.steps_for(selection) }
    end
  end

  def test_setup_prepares_the_database_only_for_the_groups_that_use_it
    assert_equal "bin/setup --skip-server --skip-db", CI_PLAN.steps_for("lint").first.command
    assert_equal "bin/setup --skip-server", CI_PLAN.steps_for("system:1/4").first.command
    assert_equal "bin/setup --skip-server", full_run.first.command
  end

  def test_a_group_list_keeps_the_order_of_the_full_run
    assert_equal CI_PLAN.steps_for("unit,seeds").map(&:title), CI_PLAN.steps_for("seeds, unit").map(&:title)
  end
end
