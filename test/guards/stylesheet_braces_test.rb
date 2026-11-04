# Pure Ruby : les feuilles de app/assets/stylesheets sont servies sans compilation (Propshaft) ; une accolade fermante en trop
# n'y lève aucune erreur, mais le navigateur jette la règle suivante (chantier sujet-comme-une-epreuve : `.ps-cards` perdait sa grille).
require "minitest/autorun"

class StylesheetBracesTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_every_stylesheet_closes_each_block_once
    Dir[File.join(ROOT, "app/assets/stylesheets/**/*.css")].each do |file|
      depth = 0
      css = File.read(file).gsub(%r{/\*.*?\*/}m) { "\n" * it.count("\n") }.gsub(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/, "")
      css.each_line.with_index(1) do |line, number|
        depth += line.count("{") - line.count("}")
        assert depth >= 0, "#{file.delete_prefix("#{ROOT}/")}:#{number} : accolade fermante en trop"
      end
      assert_equal 0, depth, "#{file.delete_prefix("#{ROOT}/")} : bloc non fermé"
    end
  end
end
