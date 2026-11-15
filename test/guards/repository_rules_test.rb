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

  # Zeitwerk autoloads every .rb under app/ (except assets, javascript, views) and under lib/ (except assets and tasks): config/application.rb
  # `autoload_lib(ignore: %w[assets tasks])`. Loading such a file by hand is never needed, and it hides code from the coverage measure:
  # a `require` at the top of a .rake file ran before SimpleCov started and took 118 lines and 51 branches out of the measure while the CI
  # showed 100 % (chantier couverture-locale-et-train-divergent, conventions.md §7 « Ne pas charger à la main… »).
  AUTOLOADED_ROOTS = %w[app lib].freeze
  NOT_AUTOLOADED = %w[app/assets app/javascript app/views lib/assets lib/tasks].freeze
  MANUAL_LOAD = /\A\s*(?:require|require_relative|load)\b[\s(]*(.*)/
  # Everything that runs inside the Rails process. `script/` and `docs/` hold standalone Ruby (no Rails, so no Zeitwerk): they load the
  # pure domain by hand on purpose (e.g. script/contenus/valider.rb) and are out of the rule.
  SCANNED = %w[app/**/*.rb lib/**/*.{rb,rake} config/**/*.rb db/**/*.rb test/**/*.rb Rakefile config.ru bin/*].freeze
  SKIPPED_DIRS = %r{\A(node_modules|vendor|tmp|log|storage|public|android)/}

  def scanned_files
    ruby_files(*SCANNED).uniq.reject { |file| file.match?(SKIPPED_DIRS) || !File.file?(File.join(ROOT, file)) }
  end

  def autoloaded?(relative)
    return false unless relative.end_with?(".rb") && AUTOLOADED_ROOTS.any? { relative.start_with?("#{it}/") }

    NOT_AUTOLOADED.none? { relative.start_with?("#{it}/") }
  end

  # The repo-relative file a manual load would resolve to, or nil when the argument is not a literal path.
  def hand_loaded_path(file, line)
    argument = line[MANUAL_LOAD, 1] or return
    literal = argument[/["']([^"']+)["']/, 1] or return
    root_based = argument.include?("Rails.root") || argument.include?("File.expand_path")
    base = line.start_with?(/\s*require_relative/) ? File.dirname(file) : nil
    candidates = base ? [ File.join(base, literal) ] : (root_based ? [ literal ] : [ "lib/#{literal}" ] + Dir[File.join(ROOT, "app/*")].map { "app/#{File.basename(it)}/#{literal}" })
    candidates.map { File.expand_path(it, ROOT).delete_prefix("#{ROOT}/").then { |path| path.end_with?(".rb") ? path : "#{path}.rb" } }
              .find { |path| File.file?(File.join(ROOT, path)) }
  end

  def hand_loaded_autoloaded_code
    scanned_files.flat_map do |file|
      File.foreach(File.join(ROOT, file)).filter_map do |line|
        target = hand_loaded_path(file, line)
        "#{file} → #{target}" if target && autoloaded?(target)
      end
    end
  end

  def test_no_file_loads_by_hand_the_code_zeitwerk_autoloads
    assert_operator scanned_files.size, :>, 500, "la garde ne balaie presque rien : le motif de fichiers est cassé"
    assert_empty hand_loaded_autoloaded_code, "Zeitwerk autocharge app/ et lib/ (hors assets et tasks) : pas de require/load à la main, la constante suffit (conventions.md §7)"
  end

  def test_the_manual_load_guard_sees_every_way_of_writing_it
    {
      %(require "contenus/corrections_production") => true,
      %(require Rails.root.join("lib/contenus/corrections_production")) => true,
      %(require Rails.root.join("lib/contenus/corrections_production").to_s) => true,
      %(require_relative "../../lib/contenus/corrections_production") => true,
      %(  load Rails.root.join("lib/contenus/corrections_production.rb")) => true,
      %(require "json") => false,
      %(require "test_helper") => false,
      %(require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s) => false,
      %(require Rails.root.join("script/ci/scope").to_s) => false
    }.each do |line, offence|
      target = hand_loaded_path("test/tasks/example_test.rb", line)

      assert_equal offence, !target.nil? && autoloaded?(target), "mal classé : #{line}"
    end
  end

  # ADR-0052 §4, amended by ADR-0108 §4: the only condition allowed on the worker is a PR environment.
  def test_the_solid_queue_worker_always_runs_inside_puma
    puma = File.read(File.join(ROOT, "config/puma.rb"))
    declarations = puma.lines.map(&:strip).grep(/solid_queue/).reject { |line| line.start_with?("#") }

    assert_equal [ "plugin :solid_queue unless PrEnvironment.active?" ], declarations,
                 "ADR-0052 amendé par ADR-0108 : `plugin :solid_queue unless PrEnvironment.active?`, sans autre condition, dans config/puma.rb"
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

  # IL-02 (ADR-0085, Lot F of inscription-eleve-sans-code), amended by ADR-0109: the classroom
  # code is back, at 6 symbols, read by `Entities::Classroom::JoinCode`. What stays gone is the old code's rotation date and the
  # old way in (`JoinWithCode`): a code is never rotated on its own, it changes with the link.
  def test_the_old_classroom_join_code_stays_gone
    offenders = ruby_files("app/**/*.{rb,erb,js}", "config/**/*.{rb,yml}", "db/seeds/**/*.rb", "script/**/*.rb").select do |file|
      File.read(File.join(ROOT, file)).match?(/join_code_rotated_at|JoinWithCode|join_with_code/)
    end

    assert_empty offenders, "ADR-0085 amendé par ADR-0109 : le code de classe ne tourne pas seul, il change avec le lien : #{offenders.join(', ')}"
  end

  # A Yarn advisory is ignored only through this register, each with its date of re-examination (chantier
  # audit-yarn-braces). Past that date the guard fails: the exception is re-examined, never forgotten.
  AUDIT_EXCEPTIONS = {
    # braces <= 3.0.3 (GHSA-vfj7-8cjw-p6xm), stack exhaustion on deeply nested patterns; build-time only
    # (@tailwindcss/cli -> @parcel/watcher, fast-glob -> micromatch), no patched version published on 2026-10-03 nor on
    # 2026-10-19 nor on 2026-11-01 (latest: 3.0.3).
    "1240992" => Date.new(2026, 11, 15)
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
