require "test_helper"

module Assessment
  class BadgesHelperTest < ActionView::TestCase
    include ComprehensionHelper # le trophée de badge_pill
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
    # CA-F3 : une note est verte à 14/20 et plus, en couleur d'encre sinon, jamais rouge.
    test "une note s'affiche en vert dès 14/20, en encre en dessous, jamais en rouge" do
      assert_equal %w[text-ink text-ink text-success text-success text-ink], [ 0, 67, 68, 100, nil ].map { grade_class(it) }
      assert_equal "13/20", grade_label(67)
      assert_equal "14/20", grade_label(68)
      assert_no_match(/error|struggling|signal-red/, [ 0, 10, 50, 99, nil ].map { grade_class(it) }.join(" "))
    end

    # UDR enseignant §3.1 : trophée de la couleur du palier sur l'icône seule, pastille neutre ; un badge à zéro est caché.
    test "badge_pill porte le trophée du palier sur une pastille neutre, et disparaît à zéro" do
      self.rendered = self.class.content_class.new(badge_pill(:gold, count: 3).to_s)

      assert_select "span.ui-badge.bg-mist.border.border-line.text-ink", text: "Or 3" do
        assert_select "svg.text-gold[aria-hidden=true]"
      end
      assert_nil badge_pill(:silver, count: 0)
    end

    test "badge_pill nomme chacun des quatre paliers et refuse un palier inconnu" do
      labels = %i[bronze silver gold diamond].map { Nokogiri::HTML5.fragment(badge_pill(it, count: 1)).text.squish }

      assert_equal [ "Bronze 1", "Argent 1", "Or 1", "Diamant 1" ], labels
      assert_raises(KeyError) { badge_pill(:platinum, count: 1) }
    end
  end
end
