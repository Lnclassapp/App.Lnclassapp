# Pure Ruby, like the domain purity test: the rules the pre-commit enforces on
# staged files, enforced by the CI on the whole tree (conventions.md §5 and §7).
require "minitest/autorun"

class RepositoryRulesTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  HITL = /\A\s*#\s*(🧠|🔌|🌐|⚡)/

  def ruby_files(*globs)
    globs.flat_map { |glob| Dir[File.join(ROOT, glob)] }.map { |file| file.delete_prefix("#{ROOT}/") }
  end

  def test_every_ruby_file_of_app_opens_with_a_hitl_header
    missing = ruby_files("app/**/*.rb").reject do |file|
      File.foreach(File.join(ROOT, file)).first(5).any? { |line| line.match?(HITL) }
    end

    assert_empty missing, "En-tête HITL absent (conventions.md §5) : #{missing.join(', ')}"
  end

  def test_no_coverage_exclusion_in_app_or_lib
    offenders = ruby_files("app/**/*.rb", "lib/**/*.rb").select { |file| File.read(File.join(ROOT, file)).include?(":nocov:") }

    assert_empty offenders, "« # :nocov: » est interdit (ADR-0024) : #{offenders.join(', ')}"
  end

  def test_the_solid_queue_worker_always_runs_inside_puma
    puma = File.read(File.join(ROOT, "config/puma.rb"))

    assert_match(/^plugin :solid_queue$/, puma, "ADR-0052 : `plugin :solid_queue` sans condition dans config/puma.rb")
  end

  def test_kamal_is_gone
    assert_empty ruby_files("config/deploy*.yml", ".kamal/*", "bin/kamal"), "ADR-0052 : Kamal n'est pas repris"
  end
end
