require "test_helper"

# UDR-0062 §3.1 : un seul helper rend l'échéance, chez l'élève (étiquette) et chez l'enseignant (date absolue).
class DueDateHelperTest < ActionView::TestCase
  helper ComponentsHelper

  # Lundi 5 octobre 2026, à Abidjan.
  TODAY = Date.new(2026, 10, 5)

  def badge(due_on, **options)
    html = due_badge(due_on, today: TODAY, **options)
    html && Nokogiri::HTML.fragment(html).at("span")
  end

  def assert_badge(due_on, text, tone:, icon:)
    span = badge(due_on)

    assert_equal text, span.text.squish
    assert_includes span["class"], ComponentsHelper::BADGE_TONES.fetch(tone)[:chip]
    assert_equal Nokogiri::HTML.fragment(ui_icon(icon, variant: :mini)).at("path")["d"], span.at("svg path")["d"], icon
    assert_equal "true", span.at("svg")["aria-hidden"]
  end

  test "sans échéance, ou exercice terminé : rien" do
    assert_nil badge(nil)
    assert_nil badge(TODAY + 1, done: true)
    assert_nil badge(TODAY - 3, done: true)
  end

  test "le jour même : « À rendre aujourd'hui », en ambre" do
    assert_badge TODAY, "À rendre aujourd'hui", tone: :warning, icon: "clock"
  end

  test "le lendemain : « À rendre demain », en ambre" do
    assert_badge TODAY + 1, "À rendre demain", tone: :warning, icon: "clock"
  end

  test "de deux à sept jours : le jour seul, en minuscule, en neutre" do
    assert_badge TODAY + 2, "À rendre mercredi", tone: :neutral, icon: "clock"
    assert_badge TODAY + 5, "À rendre samedi", tone: :neutral, icon: "clock"
    assert_badge TODAY + 7, "À rendre lundi", tone: :neutral, icon: "clock"
  end

  test "au-delà d'une semaine : le jour et la date abrégés, en neutre" do
    assert_badge TODAY + 8, "À rendre mar. 13 oct.", tone: :neutral, icon: "clock"
  end

  test "la veille : « En retard · prévu hier », en ambre" do
    assert_badge TODAY - 1, "En retard · prévu hier", tone: :warning, icon: "exclamation-circle"
  end

  test "avant la veille : le jour et la date, en ambre" do
    assert_badge TODAY - 6, "En retard · prévu mardi 29 sept.", tone: :warning, icon: "exclamation-circle"
  end

  test "l'étiquette est petite par défaut, et sa taille se choisit" do
    assert_includes badge(TODAY)["class"], ComponentsHelper::BADGE_SIZES[:sm]
    assert_includes Nokogiri::HTML.fragment(due_badge(TODAY, today: TODAY, size: :md)).at("span")["class"],
                    ComponentsHelper::BADGE_SIZES[:md]
  end

  test "aujourd'hui est la date d'Abidjan par défaut" do
    travel_to Time.utc(2026, 10, 5, 23, 30) do
      assert_equal "À rendre aujourd'hui", Nokogiri::HTML.fragment(due_badge(TODAY)).text.squish
    end
  end

  test "chez l'enseignant : la date absolue, ou « Sans date limite »" do
    assert_equal "Pour jeu. 8 oct.", due_for_teacher(Date.new(2026, 10, 8))
    assert_equal "Pour lun. 12 oct.", due_for_teacher(Date.new(2026, 10, 12))
    assert_equal "Sans date limite", due_for_teacher(nil)
  end

  # UDR-0062 §3.4 : le toast d'assignation finit sur la date ; le point abréviatif du mois tient lieu de point final.
  test "en fin de phrase : la date longue avec un seul point final" do
    assert_equal "jeudi 8 oct.", due_closing(Date.new(2026, 10, 8))
    assert_equal "jeudi 6 mai.", due_closing(Date.new(2027, 5, 6))
    assert_equal "mardi 2 mars.", due_closing(Date.new(2027, 3, 2))
  end

  test "les formats de la charte (§12) sont ceux de la locale" do
    assert_equal "jeu. 8 oct.", I18n.l(Date.new(2026, 10, 8), format: :due_short)
    assert_equal "mardi 29 sept.", I18n.l(Date.new(2026, 9, 29), format: :due_long)
  end
end
