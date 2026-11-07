require "test_helper"
require "open3"
require "tmpdir"

# Chantier flux-allege, proposition 10 : la mesure mensuelle lit l'historique git de Develop. Le script tourne dans un
# dépôt jetable dont chaque commit a une date fixe.
class MesureSobrieteTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/mesure/sobriete").to_s

  test "one PR of two commits, a catch-up merge and an index-only commit are counted on the main line" do
    Dir.mktmpdir do |repo|
      commit(repo, "base", "app/a.rb", "2026-10-01T08:00:00")
      git(repo, "checkout", "-q", "-b", "feature/x")
      commit(repo, "lot 1", "app/b.rb", "2026-10-02T08:00:00")
      git(repo, "checkout", "-q", "Develop")
      commit(repo, "index", "docs/chantiers/README.md", "2026-10-02T09:00:00")
      git(repo, "checkout", "-q", "feature/x")
      merge(repo, "Merge branch 'Develop' into feature/x", "Develop", "2026-10-02T10:00:00")
      commit(repo, "lot 2", "docs/chantiers/x/journal.md", "2026-10-03T07:00:00")
      git(repo, "checkout", "-q", "Develop")
      merge(repo, "Merge pull request #1 from o/feature/x", "feature/x", "2026-10-03T09:00:00")

      output, status = Open3.capture2e(clean_env, SCRIPT, "--depuis", "2026-10-01", "--jusqu-a", "2026-10-05", "--ref", "Develop", chdir: repo)

      assert status.success?, output
      assert_includes output, "## Sobriété — 2026-10-01 → 2026-10-05 (Develop, 4 jours)"
      assert_includes output, "| Commits hors fusion par jour | 1,0 | en baisse |"
      assert_includes output, "| PR fusionnées (commit de fusion · squash) | 1 · 0 | — |"
      assert_includes output, "| Commits par PR, PR à commit de fusion (moyenne · médiane) | 2,0 · 2 | ≤ 3 |"
      assert_includes output, "| Durée de vie d'une branche (médiane, heures) | 25,0 | < 24 |"
      assert_includes output, "| Branches de plus d'un jour | 1 sur 1 | 0 |"
      assert_includes output, "| Fusions de rattrapage (Develop dans une branche) | 1 | en baisse |"
      assert_includes output, "| Commits qui touchent l'index `docs/chantiers/README.md` (dont seul) | 1 (1) | — (0) |"
      assert_includes output, "| Commits qui ne touchent que `docs/`, hors leçons | 2 sur 4 (50 %) | en baisse |"
    end
  end

  test "an unknown ref or reversed dates stop the script" do
    Dir.mktmpdir do |repo|
      commit(repo, "base", "a.rb", "2026-10-01T08:00:00")

      assert_not sobriete(repo, "--ref", "nope").last.success?
      output, status = sobriete(repo, "--depuis", "2026-10-05", "--jusqu-a", "2026-10-01", "--ref", "Develop")
      assert_not status.success?
      assert_includes output, "--depuis doit précéder --jusqu-a"
    end
  end

  private

  def clean_env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }

  def sobriete(repo, *args) = Open3.capture2e(clean_env, SCRIPT, *args, chdir: repo)

  def git(repo, *args, date: nil)
    env = clean_env.merge(date ? { "GIT_AUTHOR_DATE" => "#{date}Z", "GIT_COMMITTER_DATE" => "#{date}Z" } : {})
    output, status = Open3.capture2e(env, "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args)
    assert status.success?, output
  end

  def commit(repo, message, path, date)
    git(repo, "init", "-q", "-b", "Develop") unless File.directory?(File.join(repo, ".git"))
    FileUtils.mkdir_p(File.dirname(File.join(repo, path)))
    File.write(File.join(repo, path), "#{message}\n", mode: "a")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", message, date:)
  end

  def merge(repo, message, branch, date) = git(repo, "merge", "-q", "--no-ff", "-m", message, branch, date:)
end
