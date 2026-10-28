require "test_helper"

# Contenu-en-blocs (#318), Lot 0 : les libellés communs de la fiche de cours, que les lots A à H lisent tels quels.
class CourseSheetsLocaleTest < ActiveSupport::TestCase
  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", locale: :fr, raise: true, **)

  test "le nom à l'écran est « Fiche de révision » (UDR page de la leçon §2)" do
    assert_equal "Fiche de révision", t("name")
  end

  test "lexique et explications simples" do
    assert_equal [ "Lexique", "Explications simples : oui", "Explications simples : non" ],
                 [ t("glossary.button"), t("simple.label_on"), t("simple.label_off") ]
  end

  test "exercice : boutons, retours et messages globaux" do
    assert_equal [ "Vérifier", "Indice", "Correction" ], %w[check hint correction].map { t("exercise.#{it}") }
    assert_equal [ "à compléter", "juste", "à revoir" ], %w[incomplete correct wrong].map { t("exercise.#{it}") }
    assert_equal [ "Tout est juste, bravo !", "Certaines réponses sont à revoir." ], %w[all_correct some_wrong].map { t("exercise.#{it}") }
  end

  test "Je m'entraîne et pagination" do
    assert_equal [ "Voir la solution", "Nouvel exercice", "Score : 1 / 2" ],
                 [ t("practice.solution"), t("practice.next"), t("practice.score", ok: 1, total: 2) ]
    assert_equal [ "Page 2", "2 / 3" ], [ t("page_label", number: 2), t("page_counter", number: 2, total: 3) ]
  end
end
