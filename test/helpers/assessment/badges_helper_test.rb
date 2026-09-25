require "test_helper"

module Assessment
  class BadgesHelperTest < ActionView::TestCase
    Grading = Entities::Assessment::Grading

    test "les quatre paliers de Grading, à 50, 70, 80 et 100, ont leur libellé et leur teinte" do
      labels = [ 49, 50, 70, 80, 99, 100 ].map { badge_label(Grading.badge_for(it)) }

      assert_equal [ "Non acquis", "Bronze", "Argent", "Or", "Or", "Diamant" ], labels
      assert_equal [ :warning, :neutral, :gold, :info, :neutral ], [ :bronze, :silver, :gold, "diamond", nil ].map { badge_tone(it) }
    end

    test "aucun libellé de badge ne reprend un terme retiré" do
      labels = I18n.t("assessment.badges.levels").values.join(" ")

      [ "Platine", "Médaille", "Trophée" ].each { assert_no_match(/#{it}/i, labels) }
    end

    test "la maîtrise et la note sur 20 suivent Grading" do
      assert_equal [ "En difficulté", "Fragile", "Fragile", "Acquis" ], [ 49, 50, 69, 70 ].map { mastery_label(it) }
      assert_equal [ "14/20", "20/20", "0/20" ], [ 70, 100, 0 ].map { grade_label(it) }
    end
  end
end
