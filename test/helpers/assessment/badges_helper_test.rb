require "test_helper"

module Assessment
  class BadgesHelperTest < ActionView::TestCase
    Grading = Entities::Assessment::Grading

    test "les quatre paliers de Grading, dès 48, 68, 78 et 100 %, ont leur libellé et leur teinte" do
      labels = [ 47, 48, 68, 78, 99, 100 ].map { badge_label(Grading.badge_for(it)) }

      assert_equal [ "Non acquis", "Bronze", "Argent", "Or", "Or", "Diamant" ], labels
      assert_equal [ :warning, :neutral, :gold, :info, :neutral ], [ :bronze, :silver, :gold, "diamond", nil ].map { badge_tone(it) }
    end

    test "aucun libellé de badge ne reprend un terme retiré" do
      labels = I18n.t("assessment.badges.levels").values.join(" ")

      [ "Platine", "Médaille", "Trophée" ].each { assert_no_match(/#{it}/i, labels) }
    end

    test "la maîtrise et la note sur 20 suivent Grading" do
      assert_equal [ "En difficulté", "Fragile", "Fragile", "Acquis" ], [ 47, 48, 67, 68 ].map { mastery_label(it) }
      assert_equal [ "14/20", "20/20", "0/20" ], [ 70, 100, 0 ].map { grade_label(it) }
    end

    # UDR-0131 : les infobulles se lisent sur 20, calculées depuis les seuils, jamais en pourcentage.
    test "les infobulles des badges et de la maîtrise citent des notes sur 20 tirées de Grading" do
      assert_equal "Bronze dès 10/20, Argent dès 14/20, Or dès 16/20, Diamant : toutes les réponses justes.", badges_tip
      assert_equal "Acquis : 14/20 et plus. Fragile : de 10 à 13/20. En difficulté : moins de 10/20.", mastery_tip
      assert_no_match(/%/, badges_tip + mastery_tip)
    end
  end
end
