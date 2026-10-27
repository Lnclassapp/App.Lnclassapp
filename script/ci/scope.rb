# What a branch owes before it merges, and whether it already paid it (ADR-0107, chantier ci-par-train).
# bin/ci-quiet picks the level from the files the branch changed since origin/Develop:
#
#   doc    only Markdown outside the code (docs/, .claude/, the root): the guards of the group lint
#   pr     code: the guards, Rubocop on the changed files, the security group, the unit tests of the touched files
#          and of their callers, the system tests bin/system-changed selects. No setup and no coverage threshold:
#          it measures the whole suite only. Under 5 minutes.
#   train  Develop, Staging, main, --full, or a change to the dependencies or the test harness (BROAD): the whole
#          bin/ci, coverage at 100 %.
#
# A green run leaves tmp/ci-verdicts/<fingerprint>-<level>. The fingerprint is the tree of the commit without its
# Markdown: a merge of Develop that brings only documents, or a fixed sentence after a review, proves nothing new.
# Each green step leaves its own verdict too, tmp/ci-verdicts/steps/<key> (chantier ci-rejeu-cible): the key is its
# command and the fingerprint of its inputs alone (Inputs below). A step whose inputs did not move is not played again:
# a line of JavaScript replays neither the unit suite nor the import performance.
require "digest"
require "fileutils"
require "time"

class CiScope
  LEVELS = %i[doc pr train].freeze
  TRAIN_BRANCHES = %w[Develop Staging main].freeze
  CODE_DIRS = %r{\A(app|bin|config|db|lib|script|test)/}
  # The changes a pr run cannot prove: the dependencies and the test harness. Everything else (a migration, a fixture,
  # a factory, a locale, a route, the CI itself) plays the tests that name it; what they miss, the train catches.
  BROAD = %r{\A(Gemfile(\.lock)?|package\.json|yarn\.lock|\.ruby-version|test/(test_helper|application_system_test_case)\.rb)\z}
  # Changing these restyles every file: Rubocop then inspects the whole tree.
  RUBOCOP_WIDE = %w[.rubocop.yml Gemfile.lock].freeze

  def self.doc?(path) = path.end_with?(".md") && !path.match?(CODE_DIRS)

  def self.level(branch:, changed:, full: false)
    return :train if full || TRAIN_BRANCHES.include?(branch)
    return :doc if changed.all? { doc?(it) }
    return :train if changed.any? { it.match?(BROAD) }

    :pr
  end

  # The unit tests a pr run plays: the changed test files, the mirror of each changed Ruby file (the mapping of the
  # pre-commit), and every test that names what changed: the constant of a Ruby file, the methods of a test helper
  # (test/support/), the fixture set of a fixture (`users(:`), the name of any other file, or one of its folders
  # (`docs/contenus/lecons-traitees`).
  # System tests belong to bin/system-changed.
  def self.tests_for(changed, test_files:, read: ->(path) { File.read(path) if File.exist?(path) })
    unit = test_files.reject { it.start_with?("test/system/") }
    selected = changed.select { unit.include?(it) }
    changed.grep(%r{\A(app|lib)/.+\.rb\z}).each do |file|
      relative = file.delete_prefix("app/").delete_suffix(".rb") # lib/x.rb keeps its lib/: test/lib/x_test.rb
      selected += [ "test/#{relative}_test.rb", "test/#{relative.split('/').first}/#{File.basename(relative)}_test.rb" ] & unit
    end
    names = changed.reject { doc?(it) || unit.include?(it) }.flat_map { names_of(it, read) }.uniq
    selected += unit.select { |test| read.call(test).to_s.then { |text| names.any? { text.include?(it) } } } if names.any?
    selected.uniq.sort
  end

  def self.names_of(path, read)
    return [ "#{File.basename(path, '.yml')}(:" ] if path.match?(%r{\Atest/fixtures/[^/]+\.yml\z})
    if path.end_with?(".rb")
      constant = File.basename(path, ".rb").split("_").map(&:capitalize).join
      return [ constant ] unless path.start_with?("test/support/")

      # A removed helper names nothing any more: the tests that still call it fail, and they are found by the train.
      source = read.call(path).to_s
      return [ constant ] + source.scan(/^\s*def (?:self\.)?(\w+[?!]?)/).flatten
    end

    folders = File.dirname(path).split("/")
    [ File.basename(path) ] + (2..folders.size).map { folders.first(it).join("/") }
  end

  # The files Rubocop inspects in a pr run, or :all when its configuration or its version moves.
  def self.rubocop_targets(changed, ruby_script: ->(path) { File.foreach(path).first.to_s.include?("ruby") })
    return :all if changed.any? { RUBOCOP_WIDE.include?(it) }

    changed.select do |path|
      next false unless File.exist?(path)

      path.match?(/\.(rb|rake|gemspec)\z|\A(Gemfile|Rakefile|config\.ru)\z/) || (path.start_with?("bin/") && ruby_script.call(path))
    end
  end

  # only: the tree lines kept (nil, every one); the Markdown outside the code never counts.
  def self.fingerprint(ls_tree, only: nil)
    kept = ls_tree.lines.map(&:chomp).reject { doc?(it.split("\t", 2).last.to_s) }
    kept = kept.select { only.call(it.split("\t", 2).last.to_s) } if only
    Digest::SHA256.hexdigest(kept.join("\n"))
  end

  # The files a step reads, as path prefixes: `only` keeps those, `except` leaves those out, `own_tests` leaves out the
  # test files of the other runs. No inputs, or any doubt: the whole tree (fail-safe). A wrong prefix can only skip a
  # step that should have played: each list below names what the step cannot read, and test/config/ci_scope_test.rb holds it.
  Inputs = Data.define(:only, :except, :own_tests) do
    def initialize(only: nil, except: [], own_tests: nil)
      super
    end

    def include?(path)
      under = ->(prefixes) { prefixes.any? { |prefix| path == prefix || path.start_with?(prefix.end_with?("/") ? prefix : "#{prefix}/") } }
      return false if only && !under.(only)
      return false if under.(except)

      own_tests.nil? || !path.match?(%r{\Atest/.+_test\.rb\z}) || path.start_with?(own_tests)
    end
  end

  # The browser and the style sheets: no Ruby process reads them, except the unit tests of FRONT_WORDS.
  FRONT = %w[app/javascript/ app/assets/stylesheets/].freeze
  INPUTS = {
    tree: nil,
    ruby: Inputs.new(except: %w[app/javascript/ app/assets/]),
    gems: Inputs.new(only: %w[Gemfile Gemfile.lock .bundler-audit.yml config/bundler-audit.yml bin/bundler-audit]),
    yarn: Inputs.new(only: %w[package.json yarn.lock .yarnrc.yml]),
    brakeman: Inputs.new(except: %w[app/javascript/ app/assets/ test/ docs/]),
    # The unit suite: neither the browser's files nor the system and performance tests. The unit tests that do read the
    # browser's files (FRONT_WORDS) are played again alone when those move (CiScope.front_readers).
    unit: Inputs.new(except: [ *FRONT, "test/system/", "test/performance/" ]),
    # The system run reads everything but the other runs' tests: a test file is loaded by its own run only.
    system: Inputs.new(own_tests: "test/system/"),
    seeds: Inputs.new(except: [ *FRONT, "test/" ]),
    # Tailwind reads app/views, app/helpers and app/javascript (@source), esbuild app/javascript.
    assets: Inputs.new(except: %w[test/ db/ docs/ app/domain/ app/infrastructure/ app/jobs/])
  }.freeze

  # The words of a unit test that reads the browser's files, or their build: over-wide on purpose (a « javascript: »
  # URL in a sanitizer test counts), so that a test reading them is never missed.
  FRONT_WORDS = /javascript|stylesheet|tailwind|esbuild|builds|\.css\b|\.js\b/i

  # The unit tests that read the browser's files: those that say so, and those calling a test helper that does.
  def self.front_readers(tests, read: ->(path) { File.read(path) if File.exist?(path) }, helpers: Dir["test/support/**/*.rb"])
    names = helpers.select { read.call(it).to_s.match?(FRONT_WORDS) }.flat_map { names_of(it, read) }
    tests.select do |test|
      text = read.call(test).to_s
      text.match?(FRONT_WORDS) || names.any? { text.match?(/\b#{Regexp.escape(it)}\b/) }
    end
  end

  # The key of a step's verdict: what it runs, and the fingerprint of what it reads.
  def self.step_key(ls_tree, command:, env: {}, inputs: nil, extra: nil)
    only = inputs && ->(path) { inputs.include?(path) }
    Digest::SHA256.hexdigest([ Array(command).join(" "), env.sort.inspect, fingerprint(ls_tree, only:), extra.to_s ].join("\0"))
  end

  # The green verdicts of this machine, one file per fingerprint and level.
  class Verdicts
    def initialize(dir) = @dir = dir

    # A level proves the levels below it: a green train covers a pr and a doc.
    def find(fingerprint, level)
      LEVELS.drop(LEVELS.index(level)).reverse_each do |proven|
        path = File.join(@dir, "#{fingerprint}-#{proven}")
        return File.read(path).strip if File.exist?(path)
      end
      nil
    end

    def record(fingerprint, level, line)
      FileUtils.mkdir_p(@dir)
      File.write(File.join(@dir, "#{fingerprint}-#{level}"), "#{line}\n")
    end

    # A green step, by its key (CiScope.step_key).
    def step?(key) = File.exist?(File.join(@dir, "steps", key))

    def record_step(key, line)
      FileUtils.mkdir_p(File.join(@dir, "steps"))
      File.write(File.join(@dir, "steps", key), "#{line}\n")
    end
  end
end
