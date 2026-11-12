# The system tests a pr run plays (ADR-0107, amended by chantier ci-scope-tests-systeme). bin/system-changed reads it.
#
# Before, a system test was played only when the branch changed it, or when it visited the route named after a changed
# view or controller. #529, #530 and #524 changed queries, views and a concern that five system tests run under other
# names: those stayed red on Develop until the train. #492 changed style sheets and selected none of the sheet tests.
#
# Now the selection also follows the map of the system tests (script/ci/system_map.yml, drawn by
# script/ci/record_system_map): each application file names the system test files that ran it (Ruby lines run,
# templates and partials rendered). A file the map cannot know is followed by its names:
#   - a style sheet, by the classes of the rules it changes, to the views, helpers and scripts that write them;
#   - a Stimulus controller, by its identifier, to the views and helpers that attach it;
#   - a locale file, by its folder, to the views, controller and helper of that resource, and to the system tests that
#     read its keys (`I18n.t("school_admin.levels.`).
# What still maps to nothing keeps the former rule (the route of its resource): a new file is reached through its
# callers, which change with it. A shared file still adds COMMON; the test named after a changed screen weighs more.
#
# The changed system tests always play. The others stay inside BUDGET seconds of recorded duration
# (script/ci/test_timings.yml): beyond it, the tests the change touches the least (a file run by every test weighs 1/n)
# are left to the train, and named. Measured on #492, #524, #529 and #530: chantier journal, §Mesure.
require "yaml"

class SystemScope
  COMMON = %w[test/system/design_system_test.rb test/system/role_homes_test.rb].freeze
  SHARED_PATHS = %r{\Aapp/(views/(components|shared|layouts)/|helpers/|assets/stylesheets/|javascript/)}
  # GitHub seconds summed per file. Two local processes play them in about half, plus Chrome's start: the step stays
  # far under five minutes on a 4-core machine.
  BUDGET = 240.0
  # Where a class, a controller identifier or a key is written: what the browser receives.
  WRITERS = %w[app/views app/helpers app/javascript app/components].freeze

  Selection = Data.define(:tests, :deferred, :unmapped)

  def self.load_map(path = File.expand_path("system_map.yml", __dir__))
    return {} unless File.exist?(path)

    data = YAML.safe_load_file(path) || {}
    tests = data.fetch("tests", [])
    data.fetch("files", {}).transform_values { |positions| positions.to_s.split.map { tests.fetch(Integer(it)) } }
  end

  # The system test files the map was drawn from: a test written since then is unknown to it.
  def self.load_mapped_tests(path = File.expand_path("system_map.yml", __dir__))
    File.exist?(path) ? (YAML.safe_load_file(path) || {}).fetch("tests", []) : nil
  end

  def self.load_timings(path = File.expand_path("test_timings.yml", __dir__))
    File.exist?(path) ? YAML.safe_load_file(path) || {} : {}
  end

  # changed: the paths the branch changed. test_files: the system tests that exist. map: application file → system
  # test files. read, read_base: a path's text now and at the base (nil when absent). diff: its diff against the base (-U0).
  # writers: the files that write classes and identifiers, with their text.
  def initialize(changed:, test_files:, map:, mapped_tests: nil, timings: {}, budget: BUDGET, read: nil, read_base: nil, diff: nil, writers: nil)
    @changed = changed
    @test_files = test_files
    @map = map
    # A test the map was not drawn from is chosen by the former rule, at full weight: the map cannot know what it runs.
    @unmapped_tests = mapped_tests ? test_files - mapped_tests : []
    @timings = timings
    @budget = budget
    @read = read || ->(path) { File.read(path) if File.exist?(path) }
    @read_base = read_base || ->(_path) { "" }
    @diff = diff || ->(_path) { "" }
    @given_writers = writers
  end

  def select
    forced = @changed.select { @test_files.include?(it) }
    weights = Hash.new(0.0)
    unmapped = []
    @changed.each do |path|
      next if path.start_with?("test/", "docs/") || path.end_with?(".md")

      share = share_of(path)
      if share.nil?
        unmapped << path
        share = spread([ former_of(path) ]) || {}
      end
      share.each { |test, weight| weights[test] += weight }
      (former_of(path) & @unmapped_tests).each { weights[it] += 1.0 } if @unmapped_tests.any?
      COMMON.each { weights[it] += 1.0 } if path.match?(SHARED_PATHS)
    end
    named = @changed.flat_map { names_of(it) }.uniq
    @test_files.each { weights[it] += 1.0 if named.include?(singular(File.basename(it, "_test.rb"))) }
    budgeted(forced.uniq, weights.reject { |test, _| forced.include?(test) || !@test_files.include?(test) }, unmapped)
  end

  # The selection before this chantier, without map nor budget: to replay what a past PR played (SYSTEM_SCOPE=former).
  def former
    tests = @changed.select { @test_files.include?(it) } + @changed.flat_map { former_of(it) }
    tests += COMMON if @changed.any? { it.match?(SHARED_PATHS) }
    Selection.new(tests: (tests & @test_files).uniq.sort, deferred: [], unmapped: [])
  end

  private

  # Each changed file weighs 1, shared among the tests it reaches: a file run by one test gives it 1, a file run by every
  # test gives each 1/n. A style sheet splits its weight among the classes it changes, each class among the tests that
  # render it. nil: neither the map, nor the file's names, nor its folder reach any test.
  def share_of(path)
    groups =
      case path
      when %r{\Aapp/assets/stylesheets/.+\.css\z} then classes_changed(path).map { rendering([ it ]) }
      when %r{\Aapp/javascript/controllers/(.+)_controller\.js\z} then [ rendering([ identifier(Regexp.last_match(1)) ]) ]
      when %r{\Aconfig/locales/(.+?)\.[a-z]{2}\.yml\z} then [ by_locale(Regexp.last_match(1)) ]
      else [ @map.fetch(path, []) ]
      end
    spread(groups)
  end

  def spread(groups)
    groups = groups.map(&:uniq).reject(&:empty?)
    return nil if groups.empty?

    groups.each_with_object(Hash.new(0.0)) { |tests, share| tests.each { share[it] += 1.0 / groups.size / tests.size } }
  end

  # The screen a test is named after weighs like a file only it runs: session_result_test.rb for
  # app/views/assessment/session_results/show.html.erb, direction_home_test.rb for direction_home_query.rb.
  def names_of(path)
    return [] if path.start_with?("test/", "docs/")

    path.split("/").drop(1).map { singular(it.sub(/\..*\z/, "").delete_prefix("_").sub(/_(controller|query|helper|policy)\z/, "")) }
  end

  def singular(name) = name.delete_suffix("s")

  # catalog/revision_more → catalog--revision-more, the identifier Stimulus registers.
  def identifier(path) = path.tr("_", "-").gsub("/", "--")

  # The tests that ran a file writing one of these names (a class, an identifier), or attached to a Stimulus controller
  # that writes one.
  def rendering(names)
    files = writers.select { |_, words| names.any? { words.include?(it) } }.keys
    scripts = files.filter_map { it[%r{\Aapp/javascript/controllers/(.+)_controller\.js\z}, 1] }.map { identifier(it) }
    files += writers.select { |_, words| scripts.any? { words.include?(it) } }.keys if scripts.any?
    files.uniq.flat_map { @map.fetch(it, []) }
  end

  # school_admin/levels → the views, controller and helper of that resource, and the tests that read its keys.
  def by_locale(name)
    prefixes = [ "app/views/#{name}/", "app/controllers/#{name}_controller.rb", "app/helpers/#{name}_helper.rb" ]
    tests = @map.select { |file, _| prefixes.any? { file.start_with?(it) } }.values.flatten
    key = "\"#{name.tr('/', '.')}."
    tests + @test_files.select { @read.call(it).to_s.include?(key) }
  end

  CLASS = /\.(-?[_a-zA-Z][\w-]*)/

  # The classes of the rules a style sheet's diff touches, read on both sides. A changed line outside every class rule
  # (an @import, a variable under :root) restyles the whole file: every class of the file, then.
  def classes_changed(path)
    old_lines, new_lines = changed_lines(@diff.call(path).to_s)
    text = @read.call(path).to_s
    found = [ [ text, new_lines ], [ @read_base.call(path).to_s, old_lines ] ].map { |source, numbers| rules_at(source, numbers) }
    classes = found.flat_map(&:first)
    return classes.uniq unless classes.empty? || found.any?(&:last)

    (classes + text.scan(CLASS).flatten).uniq
  end

  def changed_lines(diff)
    diff.scan(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/).each_with_object([ [], [] ]) do |(old, old_count, new, new_count), (olds, news)|
      olds.concat((old.to_i...(old.to_i + (old_count || 1).to_i)).to_a)
      news.concat((new.to_i...(new.to_i + (new_count || 1).to_i)).to_a)
    end
  end

  # The classes of the selectors open at the given lines, and whether one of them sits outside every class rule.
  def rules_at(text, numbers)
    stack = []
    classes = []
    outside = false
    text.each_line.with_index(1) do |line, number|
      own = line.include?("{") ? line.split("{").first.to_s : ""
      if numbers.include?(number) && !line.strip.empty? && !line.strip.start_with?("/*", "*")
        here = (stack + [ own ]).join(" ").scan(CLASS).flatten
        outside ||= here.empty?
        classes.concat(here)
      end
      line.count("{").times { stack << own }
      line.count("}").times { stack.pop }
    end
    [ classes, outside ]
  end

  # Each writer and the set of its words: a class or an identifier is found by a lookup, not by a scan per name.
  def writers
    @writers ||= (@given_writers || WRITERS.flat_map { Dir["#{it}/**/*"] }.select { File.file?(it) }.to_h { [ it, File.read(it) ] })
                 .transform_values { it.scan(/[\w-]+/).to_set }
  end

  # The former rule, kept for what the map cannot follow: the tests visiting the route of a changed view's or
  # controller's resource, by its exact helper (app/views/classroom/student_homes → `student_home_path`).
  def former_of(file)
    resource =
      case file
      when %r{\Aapp/views/(?:[^/]+/)*([^/]+)/[^/]+\z} then Regexp.last_match(1)
      when %r{\Aapp/controllers/(?:[^/]+/)*([^/]+)_controller\.rb\z} then Regexp.last_match(1)
      end
    return [] unless resource

    route = /(?<![\w.])#{Regexp.escape(resource.delete_suffix("s"))}s?_(?:path|url)\b/
    @test_files.select { @read.call(it).to_s.match?(route) }
  end

  # The forced tests always play; the others by weight, the heaviest first, the cheapest first on a tie, within the budget.
  def budgeted(forced, weights, unmapped)
    spent = forced.sum { @timings.fetch(it, 0.0).to_f }
    kept = []
    deferred = []
    weights.sort_by { |test, weight| [ -weight, @timings.fetch(test, 0.0).to_f, test ] }.each do |test, _|
      cost = @timings.fetch(test, 0.0).to_f
      next deferred << test if spent + cost > @budget

      spent += cost
      kept << test
    end
    Selection.new(tests: (forced + kept).uniq.sort, deferred: deferred.sort, unmapped: unmapped.sort)
  end
end
