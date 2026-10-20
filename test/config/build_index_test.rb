require "test_helper"
require "open3"
require "tmpdir"

# conventions.md §2 (chantier acceleration-du-flux): a decision is numbered when its chantier merges, never when it opens.
# The script runs in a throwaway repository, a copy of its own place in this one.
class BuildIndexTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/docs/build_index").to_s

  test "two pending decisions of one run get two free, distinct, consecutive numbers, in the order of their slugs" do
    in_repository do |repo|
      decision(repo, "adr/XXXX-zebre.md", "ADR-XXXX")
      decision(repo, "adr/XXXX-abeille.md", "ADR-XXXX")
      decision(repo, "udr/XXXX-ecran.md", "UDR-XXXX")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "pending")

      output, status = build_index(repo, "--number")

      assert status.success?, output
      assert_equal %w[0001-premier.md 0002-abeille.md 0003-zebre.md], decisions(repo, "adr")
      assert_equal %w[0001-ecran.md], decisions(repo, "udr")
      assert_match(/^# ADR-0002 : /, read(repo, "docs/decisions/adr/0002-abeille.md"), "son propre titre")
      assert_equal "RM docs/decisions/adr/XXXX-abeille.md -> docs/decisions/adr/0002-abeille.md\n",
                   git(repo, "status", "--porcelain", "--", "docs/decisions/adr/*abeille.md").first, "un git mv"
    end
  end

  test "the references are rewritten in docs, app, config, db, test, CLAUDE.md and .claude" do
    in_repository do |repo|
      decision(repo, "adr/XXXX-mon-choix.md", "ADR-XXXX")
      decision(repo, "udr/XXXX-mon-ecran.md", "UDR-XXXX", adr: "[XXXX](../adr/XXXX-mon-choix.md)")
      citing = %w[docs/chantiers/x/memo.md app/x.rb config/x.yml db/x.rb test/x_test.rb CLAUDE.md .claude/skills/x/SKILL.md]
      citing.each do |path|
        write(repo, path, "[ADR-XXXX-mon-choix](../decisions/adr/XXXX-mon-choix.md), UDR-XXXX-mon-ecran, ADR-XXXX-mon-choix-bis\n")
      end
      write(repo, "vendor/x.md", "ADR-XXXX-mon-choix\n")

      build_index(repo, "--number")

      citing.each do |path|
        assert_equal "[ADR-0002](../decisions/adr/0002-mon-choix.md), UDR-0001, ADR-XXXX-mon-choix-bis\n", read(repo, path), path
      end
      assert_equal "ADR-XXXX-mon-choix\n", read(repo, "vendor/x.md"), "hors des dossiers nommés"
      assert_includes read(repo, "docs/decisions/udr/README.md"), "| [0002](../adr/0002-mon-choix.md) |", "l'ADR lié de l'UDR"
    end
  end

  test "the index lists the numbered decisions; a decision already numbered does not move" do
    in_repository do |repo|
      decision(repo, "adr/XXXX-mon-choix.md", "ADR-XXXX")
      before = read(repo, "docs/decisions/adr/0001-premier.md")

      build_index(repo, "--number")

      assert_equal before, read(repo, "docs/decisions/adr/0001-premier.md")
      assert_includes read(repo, "docs/decisions/adr/README.md"), "| [0002](./0002-mon-choix.md) | mon-choix |"
      assert build_index(repo, "--check").last.success?, "l'index est à jour"
    end
  end

  test "--check refuses a pending decision on Develop, Staging and main, and accepts it on a chantier branch" do
    in_repository do |repo|
      decision(repo, "adr/XXXX-mon-choix.md", "ADR-XXXX")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "x")

      assert build_index(repo, "--check").last.success?, "branche de chantier"
      %w[Develop Staging main].each do |branch|
        git(repo, "checkout", "-q", "-B", branch)
        output, status = build_index(repo, "--check")

        assert_not status.success?, branch
        assert_includes output, "docs/decisions/adr/XXXX-mon-choix.md"
        assert_includes output, "script/docs/build_index --number"
      end
      git(repo, "checkout", "-q", "-B", "refactor/x")
      assert_not build_index(repo, "--check", "GITHUB_BASE_REF" => "Staging").last.success?, "une PR vers Staging"
    end
  end

  test "a number taken twice is refused, by --check and by --number" do
    in_repository do |repo|
      decision(repo, "adr/0001-autre.md", "ADR-0001")
      decision(repo, "adr/XXXX-mon-choix.md", "ADR-XXXX")

      %w[--check --number].each do |option|
        output, status = build_index(repo, option)

        assert_not status.success?, option
        assert_includes output, "0001", option
      end
      assert_equal %w[0001-autre.md 0001-premier.md XXXX-mon-choix.md], decisions(repo, "adr"), "rien n'a bougé"
    end
  end

  private

  def git(repo, *args)
    env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }
    Open3.capture2e(env, "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args)
  end

  def build_index(repo, *args)
    env = args.last.is_a?(Hash) ? args.pop : {}
    Open3.capture2e({ "GITHUB_BASE_REF" => nil }.merge(env), File.join(repo, "script/docs/build_index"), *args, chdir: repo)
  end

  def read(repo, path) = File.read(File.join(repo, path))

  def write(repo, path, text)
    FileUtils.mkdir_p(File.dirname(File.join(repo, path)))
    File.write(File.join(repo, path), text)
  end

  def decisions(repo, kind) = Dir.children(File.join(repo, "docs/decisions", kind)).grep(/\A\w{4}-/).sort

  def decision(repo, path, title, adr: nil)
    slug = File.basename(path, ".md").sub(/\A\w{4}-/, "")
    write(repo, "docs/decisions/#{path}", <<~MD)
      # #{title} : #{slug}
      <!-- index
      titre: #{slug}
      statut: Accepté
      #{"adr-lie: #{adr}\n" if path.start_with?("udr")}problematique: p
      -->

      | **Date** | 2026-10-20 |
    MD
  end

  # A chantier branch whose ADR index holds 0001-premier.md, and whose UDR index is empty.
  def in_repository
    Dir.mktmpdir do |repo|
      FileUtils.mkdir_p(File.join(repo, "script/docs"))
      FileUtils.cp(SCRIPT, File.join(repo, "script/docs/build_index"))
      %w[adr udr].each { write(repo, "docs/decisions/#{it}/README.md", "<!-- index:start -->\n<!-- index:end -->\n") }
      decision(repo, "adr/0001-premier.md", "ADR-0001")
      build_index(repo)
      git(repo, "init", "-q", "-b", "refactor/x")
      git(repo, "add", "-A")
      git(repo, "commit", "-q", "-m", "base")
      yield repo
    end
  end
end
