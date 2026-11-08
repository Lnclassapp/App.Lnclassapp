require "test_helper"

module Assessment
  class BadgesHelperTest < ActionView::TestCase
    include ComprehensionHelper # le trophée de badge_pill
    Grading = Entities::Assessment::Grading

    test "les quatre paliers de Grading, dès 48, 68, 78 et 100 %, ont leur libellé et leur teinte" do
      labels = [ 47, 48, 68, 78, 99, 100 ].map { badge_label(Grading.badge_for(it)) }

      assert_equal [ "Bronze", "Bronze", "Argent", "Or", "Or", "Diamant" ], labels
      assert_equal [ :warning, :neutral, :gold, :info, :neutral ], [ :bronze, :silver, :gold, "diamond", nil ].map { badge_tone(it) }
    end

    # ADR médailles lues à la clôture : medal_tag rend la médaille que la query a lue, jamais recalculée d'un score.
    test "medal_tag : trophée, nom du palier et « Médaille Or » pour les lecteurs d'écran, jamais un chiffre" do
      html = medal_tag(:gold)

      assert_equal "Or Médaille Or", Nokogiri::HTML.fragment(html).text.squish
      assert_includes html, "text-gold"
      assert_equal "Bronze Médaille Bronze", Nokogiri::HTML.fragment(medal_tag("bronze")).text.squish
      assert_no_match(%r{\d+\s*/\s*20|%}, Nokogiri::HTML.fragment(medal_tag(:gold)).text)
    end

    test "medal_tag sans médaille (copie vide ou rien de fait) : « Pas encore », sans trophée" do
      assert_equal "Pas encore", Nokogiri::HTML.fragment(medal_tag(nil)).text.squish
      assert_no_match(/<svg/, medal_tag(nil))
    end

    test "next_medal : la médaille au-dessus, rien au Diamant ni sans médaille" do
      assert_equal [ :silver, :gold, :diamond, nil, nil ], [ :bronze, :silver, :gold, :diamond, nil ].map { next_medal(it) }
    end

    test "aucun libellé de badge ne reprend un terme retiré" do
      labels = I18n.t("assessment.badges.levels").values.join(" ")

      [ "Platine", "Badge", "Trophée" ].each { assert_no_match(/#{it}/i, labels) }
    end

    test "la maîtrise et la note sur 20 suivent Grading" do
      assert_equal [ "En difficulté", "Fragile", "Fragile", "Acquis" ], [ 47, 48, 67, 68 ].map { mastery_label(it) }
      assert_equal [ "14/20", "20/20", "0/20" ], [ 70, 100, 0 ].map { grade_label(it) }
    end

    # UDR médailles : l'infobulle des médailles est en mots ; celle de la maîtrise (enseignant) se lit encore sur 20 (UDR-0131).
    test "l'infobulle des médailles est en mots, celle de la maîtrise cite des notes sur 20" do
      assert_equal "Bronze : tout exercice terminé. Argent : environ deux réponses justes sur trois. Or : plus de trois sur quatre. Diamant : toutes les réponses justes.", badges_tip
      assert_equal "Acquis : 14/20 et plus. Fragile : de 10 à 13/20. En difficulté : moins de 10/20.", mastery_tip
      assert_no_match(%r{%|/20}, badges_tip)
      assert_no_match(/%/, mastery_tip)
    end
    test "grade_label lit encore la note sur 20 (écrans enseignant)" do
      assert_equal "13/20", grade_label(67)
      assert_equal "14/20", grade_label(68)
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
