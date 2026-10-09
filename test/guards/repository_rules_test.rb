# Pure Ruby, like the domain purity test: the rules the pre-commit enforces on
# staged files, enforced by the CI on the whole tree (conventions.md §5 and §7).
require "minitest/autorun"
require "date"
require "yaml"

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

  # Railway's builder shares its address: Docker Hub answers its anonymous pulls with « 429 Too Many Requests » and the
  # deployment fails before the first line of code (chantier dockerfile-docker-hub-429). The base image comes from the AWS mirror.
  def test_the_dockerfile_pulls_no_base_image_from_docker_hub
    images = File.readlines(File.join(ROOT, "Dockerfile")).filter_map { |line| line[/^FROM\s+(?:--platform=\S+\s+)?(\S+)/, 1] }
    from_hub = images.reject { |image| image.start_with?("public.ecr.aws/", "base", "build") }

    assert_empty from_hub, "Docker Hub refuse les pulls anonymes du builder Railway (429) : utiliser public.ecr.aws/docker/library/… : #{from_hub.join(', ')}"
  end

  def test_kamal_is_gone
    assert_empty ruby_files("config/deploy*.yml", ".kamal/*", "bin/kamal"), "ADR-0052 : Kamal n'est pas repris"
  end

  # IL-02 (ADR-0085, Lot F of inscription-eleve-sans-code): the classroom code is gone, from the code and from the texts.
  def test_the_classroom_join_code_is_gone
    offenders = ruby_files("app/**/*.{rb,erb,js}", "config/**/*.{rb,yml}", "db/seeds/**/*.rb", "script/**/*.rb").select do |file|
      File.read(File.join(ROOT, file)).match?(/join_code|JoinCode|JoinWithCode|join_with_code/)
    end

    assert_empty offenders, "ADR-0085 : plus de code de classe : #{offenders.join(', ')}"
  end

  # A Yarn advisory is ignored only through this register, each with its date of re-examination (chantier
  # audit-yarn-braces). Past that date the guard fails: the exception is re-examined, never forgotten.
  AUDIT_EXCEPTIONS = {
    # braces <= 3.0.3 (GHSA-vfj7-8cjw-p6xm), stack exhaustion on deeply nested patterns; build-time only
    # (@tailwindcss/cli -> @parcel/watcher, fast-glob -> micromatch), no patched version published on 2026-10-03.
    "1240992" => Date.new(2026, 10, 17)
  }.freeze

  def test_every_ignored_yarn_advisory_is_registered_with_a_review_date
    ignored = Array(YAML.safe_load_file(File.join(ROOT, ".yarnrc.yml"))["npmAuditIgnoreAdvisories"]).map(&:to_s)

    assert_equal AUDIT_EXCEPTIONS.keys.sort, ignored.sort, "avis Yarn ignorés hors du registre AUDIT_EXCEPTIONS"
  end

  def test_no_ignored_yarn_advisory_is_past_its_review_date
    expired = AUDIT_EXCEPTIONS.select { |_, review_by| Date.today > review_by }.keys

    assert_empty expired, "réexaminer l'avis ignoré (mise à jour publiée ? sinon nouvelle date) : #{expired.join(', ')}"
  end
end
