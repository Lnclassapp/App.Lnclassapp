require "test_helper"
require "tmpdir"
require Rails.root.join("script/ci/scope").to_s

# ADR-0107 : a branch owes the CI of its level, and a code that already got a green verdict is not played again.
class CiScopeTest < ActiveSupport::TestCase
  def level(changed, branch: "feature/x", full: false) = CiScope.level(branch:, changed:, full:)

  test "Markdown outside the code is a doc change, wherever it lives" do
    assert_equal :doc, level([ "docs/decisions/adr/0107-x.md", "CLAUDE.md", ".claude/agents/chores.md" ])
    assert_equal :doc, level([]), "a branch with nothing new owes nothing more than the guards"
  end

  test "Markdown inside the code, or anything else, is code" do
    assert_equal :pr, level([ "docs/x.md", "app/views/teams/home.html.erb" ])
    assert_equal :pr, level([ "test/domain/README.md" ])
    assert_equal :pr, level([ "app/domain/school/x.rb", "config/locales/fr.yml" ]), "locales are not broad"
  end

  test "a change no mapping can follow plays the whole suite" do
    %w[Gemfile Gemfile.lock package.json yarn.lock test/test_helper.rb test/application_system_test_case.rb].each do |path|
      assert_equal :train, level([ "app/x.rb", path ]), path
    end
  end

  test "a migration, a fixture, a route or the CI itself stays at the pr level" do
    %w[db/migrate/1_x.rb db/schema.rb test/fixtures/users.yml config/routes.rb config/initializers/x.rb
       config/ci.rb script/ci/plan.rb bin/ci-quiet test/support/x.rb .rubocop.yml docs/contenus/a.json].each do |path|
      assert_equal :pr, level([ "app/x.rb", path ]), path
    end
  end

  test "Develop, Staging, main and --full play the train" do
    %w[Develop Staging main].each { assert_equal :train, level([ "docs/x.md" ], branch: it) }
    assert_equal :train, level([ "docs/x.md" ], full: true)
  end

  test "the tests of a pr run: the changed tests, the mirror of each file, and every test that names its constant" do
    files = {
      "test/domain/school/use_cases/close_year_test.rb" => "",
      "test/controllers/years_controller_test.rb" => "School::UseCases::CloseYear.new",
      "test/lib/text/slug_test.rb" => "",
      "test/models/other_test.rb" => "nothing",
      "test/system/years_test.rb" => "CloseYear"
    }
    tests = CiScope.tests_for(
      [ "app/domain/school/use_cases/close_year.rb", "lib/text/slug.rb", "test/models/other_test.rb", "docs/x.md" ],
      test_files: files.keys, read: files.method(:[])
    )

    assert_equal %w[test/controllers/years_controller_test.rb test/domain/school/use_cases/close_year_test.rb
                    test/lib/text/slug_test.rb test/models/other_test.rb], tests
  end

  test "a test helper plays the tests that call it; another file, those that name it, its fixture set or folder" do
    files = {
      "test/models/user_test.rb" => "users(:ada)",
      "test/integration/schema_test.rb" => "config/schemas/course.v1.json",
      "test/infrastructure/lessons_test.rb" => 'glob("docs/contenus/lecons/**/*.json")',
      "test/models/other_test.rb" => "nothing",
      "test/support/factories/identity.rb" => "module Factories\n  def create_teacher(name)\n  end\nend",
      "test/domain/teacher_test.rb" => "create_teacher(\"Ada\")"
    }
    tests = CiScope.tests_for(
      [ "test/support/factories/identity.rb", "test/support/gone.rb", "test/fixtures/users.yml", "config/schemas/course.v1.json", "docs/contenus/lecons/tle/a.json" ],
      test_files: files.keys.grep(/_test\.rb\z/), read: files.method(:[])
    )

    assert_equal %w[test/domain/teacher_test.rb test/infrastructure/lessons_test.rb test/integration/schema_test.rb
                    test/models/user_test.rb], tests
  end

  test "the flat fallback of the pre-commit mapping: same first segment, base name" do
    files = { "test/controllers/years_controller_test.rb" => "" }
    tests = CiScope.tests_for([ "app/controllers/school/years_controller.rb" ], test_files: files.keys, read: files.method(:[]))

    assert_equal [ "test/controllers/years_controller_test.rb" ], tests
  end

  test "Rubocop inspects the changed Ruby files, or the whole tree when its configuration moves" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p(%w[app bin])
        %w[app/x.rb app/y.html.erb bin/ruby_tool bin/shell_tool Gemfile].each { File.write(it, "") }
        script = ->(path) { path == "bin/ruby_tool" }
        changed = %w[app/x.rb app/y.html.erb app/gone.rb bin/ruby_tool bin/shell_tool Gemfile docs/a.md]

        assert_equal %w[app/x.rb bin/ruby_tool Gemfile], CiScope.rubocop_targets(changed, ruby_script: script)
        assert_equal :all, CiScope.rubocop_targets([ "app/x.rb", ".rubocop.yml" ], ruby_script: script)
        assert_empty CiScope.rubocop_targets([ "docs/a.md" ], ruby_script: script)
      end
    end
  end

  test "the fingerprint ignores the Markdown outside the code, nothing else" do
    tree = "100644 blob aaa\tapp/x.rb\n100644 blob bbb\tdocs/a.md\n"

    assert_equal CiScope.fingerprint(tree), CiScope.fingerprint(tree.sub("bbb", "ccc"))
    assert_not_equal CiScope.fingerprint(tree), CiScope.fingerprint(tree.sub("aaa", "ddd"))
    assert_not_equal CiScope.fingerprint(tree), CiScope.fingerprint(tree + "100644 blob eee\tapp/README.md\n")
  end

  test "a green level proves the levels below it, never above" do
    Dir.mktmpdir do |dir|
      verdicts = CiScope::Verdicts.new(File.join(dir, "verdicts"))
      assert_nil verdicts.find("f1", :doc)

      verdicts.record("f1", :pr, "Preuve pr")
      assert_equal "Preuve pr", verdicts.find("f1", :doc)
      assert_equal "Preuve pr", verdicts.find("f1", :pr)
      assert_nil verdicts.find("f1", :train)
      assert_nil verdicts.find("f2", :doc), "another code"

      verdicts.record("f1", :train, "Preuve train")
      assert_equal "Preuve train", verdicts.find("f1", :pr)
    end
  end
end
