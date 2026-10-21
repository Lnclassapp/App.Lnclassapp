require "test_helper"
require "open3"
require "tmpdir"

# Chantier tester-pr-en-local: bin/tester-pr puts a pull request (or a branch) on the owner's machine, prepares the
# development database and starts bin/dev. It runs here in a throwaway clone whose bin/setup, bin/rails and bin/dev only
# write down how they were called.
class TesterPrTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("bin/tester-pr").to_s

  test "without a pull request or a branch, it prints its usage and does nothing" do
    in_clone do |clone|
      output, status = tester_pr(clone)

      assert_not status.success?
      assert_includes output, "Usage : bin/tester-pr <numéro-de-PR | branche> [--telephone] [--reset] [--demo] [--activite]"
      assert_empty calls(clone)
    end
  end

  test "a pull request number checks out its head, prepares the database, seeds it and starts bin/dev" do
    in_clone do |clone, commits|
      output, status = tester_pr(clone, "7")

      assert status.success?, output
      assert_equal commits[:pull], head(clone)
      assert_equal [ "bin/setup --skip-server", "bin/rails db:seed", "bin/dev BINDING=" ], calls(clone)
      assert_includes output, "PR n° 7"
      assert_includes output, "http://localhost:3000"
      assert_includes output, "PIN 2468"
      assert_includes output, "git switch -"
    end
  end

  test "a branch name checks out the branch as it is on origin" do
    in_clone do |clone, commits|
      output, status = tester_pr(clone, "feature/x")

      assert status.success?, output
      assert_equal commits[:branch], head(clone)
    end
  end

  test "--telephone opens the server to the local network, --reset recreates the database" do
    in_clone do |clone|
      output, status = tester_pr(clone, "--telephone", "7", "--reset")

      assert status.success?, output
      assert_equal [ "bin/setup --skip-server --reset", "bin/rails db:seed", "bin/dev BINDING=0.0.0.0" ], calls(clone)
      assert_match(%r{Téléphone \(même Wi-Fi\) : http://\S+:3000}, output)
    end
  end

  test "--demo adds the three test schools, --activite the school whose students already worked, after the accounts" do
    in_clone do |clone|
      output, status = tester_pr(clone, "7", "--demo", "--activite")

      assert status.success?, output
      assert_equal [ "bin/setup --skip-server", "bin/rails db:seed", "bin/rails runner db/seeds/demo/trois_etablissements.rb",
                     "bin/rails runner db/seeds/demo/saint_michel.rb", "bin/dev BINDING=" ], calls(clone)
      assert_includes output, "ex. 0131000101"
      assert_includes output, "élèves de la Tle D 1 0110000001 à 0110000020"
    end
  end

  test "uncommitted changes, an unknown pull request or a second target stop it before anything moves" do
    in_clone do |clone, commits|
      File.write(File.join(clone, "README.md"), "changed")
      output, status = tester_pr(clone, "7")

      assert_not status.success?
      assert_includes output, "ne sont pas commitées"
      git(clone, "checkout", "-q", "--", "README.md")

      assert_not tester_pr(clone, "999").last.success?, "PR inconnue"
      assert_not tester_pr(clone, "7", "feature/x").last.success?, "deux cibles"
      assert_not tester_pr(clone, "--inconnu").last.success?, "option inconnue"
      assert_equal commits[:base], head(clone)
      assert_empty calls(clone)
    end
  end

  private

  def git(dir, *args)
    env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }
    output, status = Open3.capture2e(env, "git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", *args)
    raise output unless status.success?

    output.strip
  end

  def tester_pr(clone, *args)
    env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }.merge("PORT" => nil, "BINDING" => nil)
    Open3.capture2e(env, File.join(clone, "bin/tester-pr"), *args, chdir: clone)
  end

  def head(clone) = git(clone, "rev-parse", "HEAD")

  def calls(clone)
    log = File.join(clone, "calls.log")
    File.exist?(log) ? File.readlines(log, chomp: true) : []
  end

  def commit(dir, file, message)
    File.write(File.join(dir, file), message)
    git(dir, "add", file)
    git(dir, "commit", "-q", "-m", message)
    git(dir, "rev-parse", "HEAD")
  end

  # A clone of an origin holding Develop, a branch feature/x and a pull request 7, with bin/tester-pr and stubs that
  # stay untracked, so that they survive every checkout.
  def in_clone
    Dir.mktmpdir do |dir|
      origin = File.join(dir, "origin.git")
      seed = File.join(dir, "seed")
      clone = File.join(dir, "clone")
      git(dir, "init", "-q", "--bare", origin)
      git(dir, "init", "-q", "-b", "Develop", seed)
      commits = { base: commit(seed, "README.md", "base") }
      git(seed, "switch", "-q", "-c", "feature/x")
      commits[:branch] = commit(seed, "branch.txt", "branch")
      git(seed, "switch", "-q", "Develop")
      git(seed, "switch", "-q", "-c", "pull")
      commits[:pull] = commit(seed, "pull.txt", "pull")
      git(seed, "push", "-q", origin, "Develop", "feature/x", "pull:refs/pull/7/head")
      git(dir, "clone", "-q", "-b", "Develop", origin, clone)

      FileUtils.mkdir_p(File.join(clone, "bin"))
      FileUtils.cp(SCRIPT, File.join(clone, "bin/tester-pr"))
      { "setup" => "bin/setup $*", "rails" => "bin/rails $*", "dev" => "bin/dev BINDING=$BINDING" }.each do |name, call|
        stub = File.join(clone, "bin", name)
        File.write(stub, "#!/usr/bin/env bash\necho \"#{call}\" >> \"$(dirname \"$0\")/../calls.log\"\n")
        FileUtils.chmod(0o755, stub)
      end
      yield clone, commits
    end
  end
end
