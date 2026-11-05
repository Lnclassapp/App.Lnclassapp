require "test_helper"
require "open3"
require "tmpdir"

# docs/workflows/contrat-de-session.md §2 (chantier contrat-de-session): the daily decision box reads the open entries of
# every chantier. The script runs in a throwaway copy of its own place in this repository.
class ATrancherTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/docs/a_trancher").to_s

  test "lists the unchecked entries of À trancher and Décisions ouvertes only, chantier by chantier" do
    in_copy do |root|
      write(root, "docs/chantiers/b-chantier/journal.md", <<~MD)
        # Journal

        ## À trancher

        - [ ] 2026-11-05 · b · libellé « Fixation » ? — appliqué : garder
        - [x] 2026-11-04 · b · déjà tranché

        ## Ce qui a dérapé

        - [ ] hors section, ignorée
      MD
      write(root, "docs/chantiers/a-chantier/plan.md", "# Plan\n\n## Décisions ouvertes\n\n- [ ] établissement en brouillon ?\n")
      write(root, "docs/chantiers/_TEMPLATE/journal.md", "## À trancher\n\n- [ ] modèle, ignoré\n")

      output, status = run_script(root)

      assert status.success?, output
      assert_equal [ "a-chantier · plan.md:5 · établissement en brouillon ?",
                     "b-chantier · journal.md:5 · 2026-11-05 · b · libellé « Fixation » ? — appliqué : garder" ], output.lines(chomp: true)
      assert_equal "2\n", run_script(root, "--count").first
    end
  end

  test "says so when nothing is open" do
    in_copy do |root|
      write(root, "docs/chantiers/c/journal.md", "## À trancher\n\n- …\n")

      assert_equal [ "Aucune décision ouverte.\n", "0\n" ], [ run_script(root).first, run_script(root, "--count").first ]
    end
  end

  private

  def in_copy
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "script/docs"))
      FileUtils.cp(SCRIPT, File.join(root, "script/docs/a_trancher"))
      yield root
    end
  end

  def write(root, path, content)
    FileUtils.mkdir_p(File.dirname(File.join(root, path)))
    File.write(File.join(root, path), content)
  end

  def run_script(root, *args) = Open3.capture2e("ruby", File.join(root, "script/docs/a_trancher"), *args)
end
