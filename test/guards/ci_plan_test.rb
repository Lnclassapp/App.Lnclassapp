# Pure Ruby, no Rails boot: bin/ci is one list of steps, and the GitHub jobs add up to exactly that list
# (feuille-de-route §2, garde-fou n° 4; ADR-0064). They run on the self-hosted runner (ADR-0068). A group missing from the workflow, played twice, or a test file
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

  def jobs = YAML.safe_load_file(WORKFLOW, aliases: true).fetch("jobs")

  SELF_HOSTED = %w[self-hosted linux lnclass].freeze
  PROMOTION_ON_GITHUB = /base_ref == 'Staging' \|\| github\.base_ref == 'main'.*ref_name == 'Staging' \|\| github\.ref_name == 'main'.*'\["ubuntu-latest"\]' \|\| '\["self-hosted", "linux", "lnclass"\]'/

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

  # ADR-0068 : the GitHub minutes ran out. A job of this workflow runs on the owner's machine; only the proof and the
  # verdict « ci » of a promotion may run on GitHub, and only through that one expression. A new job on ubuntu-latest
  # would reopen the leak: it fails here.
  def test_only_the_proof_and_the_verdict_of_a_promotion_run_on_a_github_runner
    jobs.except("proof", "ci").each do |name, job|
      assert_equal SELF_HOSTED, job["runs-on"], "le job « #{name} » doit tourner sur le runner auto-hébergé (ADR-0068)"
    end
    jobs.slice("proof", "ci").each do |name, job|
      assert_match PROMOTION_ON_GITHUB, job["runs-on"], "« #{name} » : GitHub pour une promotion seulement (ADR-0068)"
    end
    assert_match(/\(needs\.proof\.result == 'failure' \|\| \(needs\.proof\.outputs\.tested == 'true' &&/, jobs.fetch("ci")["runs-on"],
                 "« ci » : GitHub seulement si la preuve suffit, ou si elle n'a jamais eu de runner")
  end

  # ADR-0068 : on the owner's machine, a job without its own PostgreSQL would fall back on port 5432, the owner's
  # development server, with the same credentials. Every job that plays a group needing the database has its service
  # container and passes its port to bin/ci.
  def test_a_job_playing_a_database_group_brings_its_own_postgresql
    jobs.each do |name, job|
      selections = job.dig("env", "CI_GROUP").to_s.include?("matrix.group") ? job.dig("strategy", "matrix", "group") : [ job.dig("env", "CI_GROUP") ].compact
      next unless selections.any? { |selection| CI_PLAN.steps_for(selection).first.command == "bin/setup --skip-server" }

      assert job.dig("services", "postgres"), "« #{name} » : groupe avec base, sans conteneur PostgreSQL"
      run = job.fetch("steps").find { it["run"] == "bin/ci" }
      assert_match(/job\.services\.postgres\.ports\['5432'\]/, run.dig("env", "PGPORT").to_s, "« #{name} » : PGPORT manquant")
    end
  end

  # ADR-0068 : the jobs run on the owner's machine, on his network. A service container (PostgreSQL, superuser with a
  # known password) is published on the loopback only, never on every interface.
  def test_service_containers_are_published_on_the_loopback_only
    ports = Dir[File.join(File.dirname(WORKFLOW), "*.yml")].flat_map do |workflow|
      YAML.safe_load_file(workflow, aliases: true).fetch("jobs").values.flat_map { (it["services"] || {}).values.flat_map { it["ports"] || [] } }
    end

    refute_empty ports
    ports.each { assert_match(/\A127\.0\.0\.1:/, it.to_s, "port « #{it} » publié sur toutes les interfaces") }
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
