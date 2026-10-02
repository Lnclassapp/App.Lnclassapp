require "test_helper"
require "open3"
require "tmpdir"
load Rails.root.join("script/ci/prove").to_s unless defined?(CiProof)

# ADR-0069 §8 : a green bin/ci in a cloud session publishes arbres/<tree> on ci/preuves. A dirty tree, a branch that
# does not contain its base, a red run or a HEAD that moved during the run publish nothing. Real git, in a temporary
# directory, against a bare remote.
class CiProveTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @remote = File.join(@dir, "remote.git")
    @work = File.join(@dir, "work")
    sh(@dir, "git", "init", "--quiet", "--bare", @remote)
    sh(@dir, "git", "clone", "--quiet", @remote, @work)
    assert_equal File.realpath(@work), File.realpath(sh(@work, "git", "rev-parse", "--show-toplevel").first.strip), "dépôt de travail isolé"
    assert_equal @remote, sh(@work, "git", "remote", "get-url", "origin").first.strip, "jamais le vrai origin"
    commit("README.md", "base")
    sh(@work, "git", "push", "--quiet", "origin", "HEAD:refs/heads/Develop")
    commit("app.rb", "feature")
  end

  teardown { FileUtils.remove_entry(@dir) }

  # Every GIT_* variable of the caller is removed. Under a git hook (the pre-commit plays this test), git sets GIT_DIR
  # and GIT_INDEX_FILE: kept, they sent these commands to the real repository and its real origin (2026-10-02).
  ISOLATED = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }.merge("GIT_AUTHOR_NAME" => "t", "GIT_AUTHOR_EMAIL" => "t@t",
                                                                 "GIT_COMMITTER_NAME" => "t", "GIT_COMMITTER_EMAIL" => "t@t",
                                                                 "GIT_CONFIG_NOSYSTEM" => "1", "HOME" => Dir.tmpdir)

  def sh(dir, *args, env: {})
    out, status = Open3.capture2(ISOLATED.merge(env), *args, chdir: dir, err: File::NULL)
    [ out, status.success? ]
  end

  def commit(file, text)
    File.write(File.join(@work, file), text)
    sh(@work, "git", "add", file)
    sh(@work, "git", "commit", "--quiet", "-m", text)
  end

  def git = ->(*args, env: {}) { sh(@work, "git", *args, env:) }

  def prove(run: -> { [ true, [ "2754 runs, 0 failures" ] ] }) = CiProof.new(git:, run:, clock: -> { Time.utc(2026, 10, 2, 12) })

  def tree = sh(@work, "git", "rev-parse", "HEAD^{tree}").first.strip

  def proof_of(tree) = sh(@remote, "git", "show", "ci/preuves:arbres/#{tree}")

  test "a green run publishes arbres/<tree> on ci/preuves, with the commit, the base and the summary of bin/ci" do
    assert_equal tree, prove.call(base: "Develop")

    text, found = proof_of(tree)
    assert found
    assert_includes text, "arbre: #{tree}"
    assert_includes text, "commit: #{sh(@work, 'git', 'rev-parse', 'HEAD').first.strip}"
    assert_includes text, "base: Develop"
    assert_includes text, "date: 2026-10-02T12:00:00Z"
    assert_includes text, "  2754 runs, 0 failures"
  end

  test "a second proof keeps the first one: the branch only grows" do
    first = prove.call(base: "Develop")
    commit("app.rb", "second")
    second = prove.call(base: "Develop")

    refute_equal first, second
    assert proof_of(first).last
    assert proof_of(second).last
    assert_equal "2", sh(@remote, "git", "rev-list", "--count", "ci/preuves").first.strip
  end

  test "a dirty work tree, a branch without its base, a red run or a HEAD that moved publish nothing" do
    File.write(File.join(@work, "app.rb"), "dirty")
    assert_raises(CiProof::Refused) { prove.call(base: "Develop") }
    sh(@work, "git", "checkout", "--quiet", "app.rb")

    sh(@work, "git", "push", "--quiet", "origin", "HEAD~1:refs/heads/Staging")
    commit("other.rb", "elsewhere")
    sh(@work, "git", "push", "--quiet", "origin", "HEAD:refs/heads/Staging")
    sh(@work, "git", "reset", "--quiet", "--hard", "HEAD~1")
    assert_raises(CiProof::Refused) { prove.call(base: "Staging") }

    assert_raises(CiProof::Refused) { prove(run: -> { [ false, [] ] }).call(base: "Develop") }
    assert_raises(CiProof::Refused) { prove(run: -> { commit("late.rb", "late") && [ true, [] ] }).call(base: "Develop") }

    refute sh(@remote, "git", "rev-parse", "--verify", "--quiet", "ci/preuves").last, "aucune preuve publiée"
  end
end
