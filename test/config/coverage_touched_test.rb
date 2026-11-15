require "test_helper"
require "open3"
require "tmpdir"
require Rails.root.join("script/ci/coverage_touched").to_s

# ADR-0107 §10 : the pr level says which lines and branches of the touched files no test of the change plays.
class CoverageTouchedTest < ActiveSupport::TestCase
  ROOT = "/repo".freeze
  FILE = "app/controllers/catalog/courses_controller.rb".freeze

  def result(lines:, branches: {}, file: FILE) = { "unit pr" => { "coverage" => { "#{ROOT}/#{file}" => { "lines" => lines, "branches" => branches } } } }

  def gaps(resultset, files = [ FILE ]) = CoverageTouched.gaps(resultset, files, root: ROOT)

  test "only the Ruby files of app and lib that still exist are touched" do
    changed = %w[app/a.rb lib/b.rb lib/tasks/c.rake app/views/x.erb test/a_test.rb app/gone.rb app/a.rb]
    assert_equal %w[app/a.rb lib/b.rb], CoverageTouched.touched(changed, exist: ->(path) { path != "app/gone.rb" })
  end

  test "a file whose lines and branches are all played has no gap" do
    gap = gaps(result(lines: [ nil, 2, 1 ], branches: { "[:if, 0, 1, 2, 3, 4]" => { "[:then, 1, 2, 3, 4, 5]" => 1, "[:else, 2, 3, 4, 5, 6]" => 2 } })).first
    assert_predicate gap, :clean?
    assert_empty CoverageTouched.report([ gap ])
  end

  test "a branch no test plays is named with its line, even when every line is played" do
    # The case of the train #631: 100 % of the lines, a `then` and an `else` that nothing takes.
    branches = { "[:if, 0, 10, 4, 10, 40]" => { "[:then, 1, 10, 4, 10, 20]" => 0, "[:else, 2, 10, 4, 10, 40]" => 3 },
                 "[:if, 3, 20, 4, 22, 40]" => { "[:then, 4, 21, 4, 21, 20]" => 1, "[:else, 5, 22, 4, 22, 40]" => 0 } }
    gap = gaps(result(lines: [ 1, 1 ], branches:)).first
    assert_empty gap.lines
    assert_equal [ "line 10: then of the if on line 10", "line 22: else of the if on line 20" ], gap.branches
    report = CoverageTouched.report([ gap ]).join("\n")
    assert_includes report, "#{FILE}: lines 100.0 %, branches 50.0 %"
    assert_includes report, "branch not played, line 22: else of the if on line 20"
  end

  test "a line no test plays is named" do
    gap = gaps(result(lines: [ 1, 0, nil, 0 ])).first
    assert_equal [ 2, 4 ], gap.lines
    assert_includes CoverageTouched.report([ gap ]).join("\n"), "lines not played: 2, 4"
  end

  test "a file at 0 % says that it may have been loaded before the measure started" do
    report = CoverageTouched.report(gaps(result(lines: [ 0, 0, nil ]))).join("\n")
    assert_includes report, "loaded before SimpleCov started"
    refute_includes CoverageTouched.report(gaps(result(lines: [ 1, 0 ]))).join("\n"), "loaded before SimpleCov started"
  end

  test "a result of another command name or of another worker adds to the first" do
    first = result(lines: [ 0, 1 ])
    second = { "unit 2/3" => { "coverage" => { "#{ROOT}/#{FILE}" => { "lines" => [ 3, 0 ], "branches" => {} } } } }
    assert_empty gaps(first.merge(second)).first.lines.then { it - [ 2 ] }, "line 1 is played by the second, line 2 by the first"
  end

  test "a touched file the result does not know is said not to be loaded" do
    gap = gaps(result(lines: [ 1 ], file: "app/other.rb")).first
    assert_equal [ :never_loaded ], gap.lines
    assert_includes CoverageTouched.report([ gap ]).join("\n"), "no test of the change loads this file"
  end

  test "files outside the touched list are ignored" do
    assert_empty gaps(result(lines: [ 0 ], file: "app/other.rb"), []).reject(&:clean?)
  end

  # #643: the files reach the script as arguments after `--`, never through a variable the shell would split on spaces.
  test "the command takes a path containing a space as one file, after the -- marker" do
    spaced = "app/models/a file.rb"
    Dir.mktmpdir do |dir|
      resultset = File.join(dir, "resultset.json")
      out = File.join(dir, "note")
      File.write(resultset, JSON.generate("unit pr" => { "coverage" => { "#{Dir.pwd}/#{spaced}" => { "lines" => [ 1, 0 ], "branches" => {} } } }))

      stdout, status = Open3.capture2(Rails.root.join("script/ci/coverage_touched").to_s, resultset, out, "--", spaced, "app/models/b.rb")

      assert_predicate status, :success?
      assert_includes stdout, "#{spaced}: lines 50.0 %"
      assert_includes stdout, "app/models/b.rb: no test of the change loads this file"
      refute_includes stdout, "--: no test", "the marker is not a file"
      refute_includes stdout, "app/models/a: ", "the path is not cut at the space"
      assert_includes File.read(out), spaced
    end
  end
end
