require "test_helper"
require "tmpdir"
require Rails.root.join("script/ci/system_scope").to_s

# Chantier ci-scope-tests-systeme (ADR-0107 amended): a pr run plays the system tests that ran the changed code, not only
# those named after it. Each case below is a hole the former selection left open on Develop.
class SystemScopeTest < ActiveSupport::TestCase
  TESTS = %w[
    test/system/design_system_test.rb test/system/role_homes_test.rb
    test/system/school_admin/direction_home_test.rb test/system/school_admin/departed_students_test.rb
    test/system/catalog/sheet_cards_test.rb test/system/teams/levels_test.rb test/system/homepage_test.rb
  ].freeze

  def select(changed, map: {}, texts: {}, base: {}, diffs: {}, writers: {}, timings: {}, budget: SystemScope::BUDGET)
    SystemScope.new(changed:, test_files: TESTS, map:, timings:, budget:, read: ->(path) { texts[path] },
                    read_base: ->(path) { base[path] }, diff: ->(path) { diffs[path] }, writers:).select
  end

  # The examples avoid a test named after the changed file: the name bonus would select it and hide the rule under test.
  test "a query changed under another name plays the system tests that ran it (#530)" do
    map = { "app/infrastructure/queries/assessment/medals.rb" => [ "test/system/school_admin/direction_home_test.rb" ] }

    selection = select(map.keys, map:)

    assert_equal [ "test/system/school_admin/direction_home_test.rb" ], selection.tests
    assert_empty selection.unmapped
  end

  test "a file the map does not know falls back to the route of its resource, and is named" do
    texts = { "test/system/homepage_test.rb" => "visit foo_bars_path" }

    selection = select([ "app/views/school/foo_bars/index.html.erb" ], texts:)

    assert_equal [ "test/system/homepage_test.rb" ], selection.tests
    assert_equal [ "app/views/school/foo_bars/index.html.erb" ], selection.unmapped
  end

  test "a changed system test always plays, even beyond the budget, and is never left to the train" do
    selection = select([ "test/system/homepage_test.rb", "app/x/alpha.rb" ], map: { "app/x/alpha.rb" => [ "test/system/catalog/sheet_cards_test.rb" ] },
                       timings: { "test/system/homepage_test.rb" => 500.0, "test/system/catalog/sheet_cards_test.rb" => 10.0 }, budget: 100.0)

    assert_equal [ "test/system/homepage_test.rb" ], selection.tests
    assert_equal [ "test/system/catalog/sheet_cards_test.rb" ], selection.deferred
  end

  test "a style sheet plays the tests that rendered a view writing the classes of the changed rules (#492)" do
    css = ".ps-page .ps-start {\n  margin: 0;\n}\n.ps-title {\n  color: red;\n}\n"
    writers = { "app/views/catalog/prepare_sheets/show.html.erb" => '<a class="ps-start">', "app/views/x/y.html.erb" => '<h1 class="ps-title">' }
    map = { "app/views/catalog/prepare_sheets/show.html.erb" => [ "test/system/catalog/sheet_cards_test.rb" ], "app/views/x/y.html.erb" => [ "test/system/homepage_test.rb" ] }

    selection = select([ "app/assets/stylesheets/prepare_sheet.css" ], map:, writers:, texts: { "app/assets/stylesheets/prepare_sheet.css" => css },
                       diffs: { "app/assets/stylesheets/prepare_sheet.css" => "@@ -2 +2 @@\n-  margin: 4px;\n+  margin: 0;\n" })

    assert_equal [ *SystemScope::COMMON, "test/system/catalog/sheet_cards_test.rb" ].sort, selection.tests,
                 "only the rule that changed counts; a style sheet is still a shared file"
  end

  test "a style sheet line outside any class rule restyles every class of the file, even beside a class rule" do
    css = ".ps-a {\n  color: red;\n}\n:root {\n  --x: 1px;\n}\n.ps-b {\n  color: blue;\n}\n"
    writers = { "app/views/a.html.erb" => '<p class="ps-a">', "app/views/b.html.erb" => '<p class="ps-b">' }
    map = { "app/views/a.html.erb" => [ "test/system/catalog/sheet_cards_test.rb" ], "app/views/b.html.erb" => [ "test/system/homepage_test.rb" ] }

    selection = select([ "app/assets/stylesheets/a.css" ], map:, writers:, texts: { "app/assets/stylesheets/a.css" => css },
                       diffs: { "app/assets/stylesheets/a.css" => "@@ -2 +2 @@\n-  color: pink;\n+  color: red;\n@@ -5 +5 @@\n-  --x: 2px;\n+  --x: 1px;\n" })

    assert_includes selection.tests, "test/system/homepage_test.rb", ".ps-b reads --x: its test plays"
    assert_includes selection.tests, "test/system/catalog/sheet_cards_test.rb"
  end

  test "a class removed from a rule counts on the base side" do
    writers = { "app/views/x/y.html.erb" => '<h1 class="ps-gone">' }

    selection = select([ "app/assets/stylesheets/a.css" ], map: { "app/views/x/y.html.erb" => [ "test/system/homepage_test.rb" ] }, writers:,
                       texts: { "app/assets/stylesheets/a.css" => "" }, base: { "app/assets/stylesheets/a.css" => ".ps-gone {\n  color: red;\n}\n" },
                       diffs: { "app/assets/stylesheets/a.css" => "@@ -1,3 +0,0 @@\n-.ps-gone {\n-  color: red;\n-}\n" })

    assert_equal [ *SystemScope::COMMON, "test/system/homepage_test.rb" ].sort, selection.tests
  end

  test "a class written by a Stimulus controller plays the tests of the views attaching it" do
    writers = { "app/javascript/controllers/foo_bar_controller.js" => 'this.element.classList.add("ps-open")',
                "app/views/x/y.html.erb" => '<div data-controller="foo-bar">' }

    selection = select([ "app/assets/stylesheets/a.css" ], map: { "app/views/x/y.html.erb" => [ "test/system/homepage_test.rb" ] }, writers:,
                       texts: { "app/assets/stylesheets/a.css" => ".ps-open {\n  color: red;\n}\n" },
                       diffs: { "app/assets/stylesheets/a.css" => "@@ -2 +2 @@\n-  color: blue;\n+  color: red;\n" })

    assert_equal [ *SystemScope::COMMON, "test/system/homepage_test.rb" ].sort, selection.tests
  end

  test "a Stimulus controller plays the tests that rendered a view attaching it, with the shared journeys" do
    writers = { "app/views/teams/levels/index.html.erb" => 'data-controller="catalog--revision-more"' }
    map = { "app/views/teams/levels/index.html.erb" => [ "test/system/homepage_test.rb" ] }

    selection = select([ "app/javascript/controllers/catalog/revision_more_controller.js" ], map:, writers:)

    assert_equal [ *SystemScope::COMMON, "test/system/homepage_test.rb" ].sort, selection.tests
  end

  test "a shared helper the map does not know still plays the shared journeys" do
    selection = select([ "app/helpers/foo_helper.rb" ])

    assert_equal SystemScope::COMMON.sort, selection.tests
    assert_equal [ "app/helpers/foo_helper.rb" ], selection.unmapped
  end

  test "a locale plays the views, controller and helper of its resource, and the tests reading its keys" do
    map = {
      "app/views/school_admin/signals/show.html.erb" => [ "test/system/school_admin/direction_home_test.rb" ],
      "app/controllers/school_admin/signals_controller.rb" => [ "test/system/school_admin/departed_students_test.rb" ],
      "app/helpers/school_admin/signals_helper.rb" => [ "test/system/catalog/sheet_cards_test.rb" ]
    }
    texts = { "test/system/homepage_test.rb" => 'assert_text I18n.t("school_admin.signals.show.title")' }

    selection = select([ "config/locales/school_admin/signals.fr.yml" ], map:, texts:)

    assert_equal %w[test/system/catalog/sheet_cards_test.rb test/system/homepage_test.rb
                    test/system/school_admin/departed_students_test.rb test/system/school_admin/direction_home_test.rb], selection.tests
  end

  test "beyond the budget a file run by one test weighs more than a file run by three" do
    map = { "app/x/alpha.rb" => %w[test/system/school_admin/direction_home_test.rb test/system/school_admin/departed_students_test.rb
                                   test/system/catalog/sheet_cards_test.rb], "app/x/beta.rb" => [ "test/system/homepage_test.rb" ] }
    timings = { "test/system/homepage_test.rb" => 60.0 }.merge(map["app/x/alpha.rb"].to_h { [ it, 40.0 ] })

    selection = select(map.keys, map:, timings:, budget: 60.0)

    assert_equal [ "test/system/homepage_test.rb" ], selection.tests
    assert_equal map["app/x/alpha.rb"].sort, selection.deferred, "the tests left to the train are named"
  end

  test "on equal weight the cheapest test plays first" do
    map = { "app/x/alpha.rb" => %w[test/system/school_admin/departed_students_test.rb test/system/school_admin/direction_home_test.rb] }
    timings = { "test/system/school_admin/departed_students_test.rb" => 50.0, "test/system/school_admin/direction_home_test.rb" => 30.0 }

    selection = select(map.keys, map:, timings:, budget: 30.0)

    assert_equal [ "test/system/school_admin/direction_home_test.rb" ], selection.tests
    assert_equal [ "test/system/school_admin/departed_students_test.rb" ], selection.deferred
  end

  test "the screen a test is named after plays first, before tests the change reaches as much (#529)" do
    map = { "app/views/school_admin/departed_students/index.html.erb" => TESTS.drop(2) }
    timings = TESTS.to_h { [ it, 50.0 ] }

    selection = select(map.keys, map:, timings:, budget: 50.0)

    assert_equal [ "test/system/school_admin/departed_students_test.rb" ], selection.tests
  end

  test "a system test written after the map was drawn is chosen by the former rule, even for a mapped file" do
    texts = { "test/system/homepage_test.rb" => "visit foo_bars_path" }
    map = { "app/controllers/foo_bars_controller.rb" => [ "test/system/catalog/sheet_cards_test.rb" ] }

    known = SystemScope.new(changed: map.keys, test_files: TESTS, map:, mapped_tests: TESTS, read: ->(path) { texts[path] }).select
    fresh = SystemScope.new(changed: map.keys, test_files: TESTS, map:, mapped_tests: TESTS - [ "test/system/homepage_test.rb" ],
                            read: ->(path) { texts[path] }).select

    assert_equal [ "test/system/catalog/sheet_cards_test.rb" ], known.tests, "a test the map knows is trusted to the map"
    assert_equal %w[test/system/catalog/sheet_cards_test.rb test/system/homepage_test.rb], fresh.tests
  end

  test "a file nothing reaches selects nothing and is named" do
    selection = select([ "app/domain/entities/school/new_thing.rb" ])

    assert_empty selection.tests
    assert_equal [ "app/domain/entities/school/new_thing.rb" ], selection.unmapped
  end

  test "the former selection ignores the map and the budget (SYSTEM_SCOPE=former)" do
    scope = SystemScope.new(changed: [ "app/views/school/foo_bars/index.html.erb", "app/helpers/foo_helper.rb", "test/system/homepage_test.rb" ],
                            test_files: TESTS, map: { "app/helpers/foo_helper.rb" => [ "test/system/teams/levels_test.rb" ] },
                            timings: TESTS.to_h { [ it, 500.0 ] }, budget: 1.0,
                            read: ->(path) { "visit foo_bars_path" if path == "test/system/catalog/sheet_cards_test.rb" })

    assert_equal [ *SystemScope::COMMON, "test/system/catalog/sheet_cards_test.rb", "test/system/homepage_test.rb" ].sort, scope.former.tests
  end

  test "the map file names its tests once, by position" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "system_map.yml")
      File.write(path, { "commit" => "x", "tests" => %w[test/system/a_test.rb test/system/b_test.rb], "files" => { "app/x.rb" => "1 0", "app/y.rb" => "1" } }.to_yaml)

      assert_equal({ "app/x.rb" => %w[test/system/b_test.rb test/system/a_test.rb], "app/y.rb" => %w[test/system/b_test.rb] }, SystemScope.load_map(path))
      assert_equal %w[test/system/a_test.rb test/system/b_test.rb], SystemScope.load_mapped_tests(path)
      assert_equal({}, SystemScope.load_map(File.join(dir, "missing.yml")), "no map: every file keeps the former rules")
      assert_nil SystemScope.load_mapped_tests(File.join(dir, "missing.yml"))
    end
  end

  test "documents and tests other than system tests select nothing" do
    selection = select([ "docs/x.md", "test/controllers/x_controller_test.rb" ], map: { "docs/x.md" => [ "test/system/homepage_test.rb" ] })

    assert_empty selection.tests
    assert_empty selection.unmapped
  end
end
