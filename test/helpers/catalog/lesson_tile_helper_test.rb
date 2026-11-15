require "test_helper"

# UDR XXXX écrans minimalistes style Wave §3 : l'icône d'une leçon est calculée (jamais saisie) par des règles de mots-clés,
# l'icône de la matière en repli ; chaque règle cite un pictogramme du jeu ; les leçons importées sont couvertes.
class Catalog::LessonTileHelperTest < ActionView::TestCase
  include ComponentsHelper

  test "every rule names a pictogram of the finite set, and every pictogram is used" do
    keys = Catalog::LessonTileHelper::LESSON_ICON_RULES.values.flatten(1).map(&:first)

    assert_empty keys - Catalog::LessonTileHelper::LESSON_ICONS.keys
    assert_empty Catalog::LessonTileHelper::LESSON_ICONS.keys - keys
  end

  test "the title chooses the pictogram, accents and hyphens ignored, in the order of the rules" do
    {
      [ "mathematiques", "Vecteurs et points du plan" ] => "vector",
      [ "mathematiques", "Équations et inéquations" ] => "equals",
      [ "mathematiques", "Dérivabilité et étude de fonctions" ] => "curve",
      [ "mathematiques", "Probabilité conditionnelle" ] => "dice",
      [ "mathematiques", "Propriétés de Thalès dans un triangle" ] => "geometry",
      [ "mathematiques", "Ensemble des nombres réels" ] => "numbers",
      [ "physique-chimie", "Le circuit électrique" ] => "bolt",
      [ "physique-chimie", "Les phases de la Lune" ] => "light",
      [ "physique-chimie", "Les alcanes" ] => "flask",
      [ "physique-chimie", "Mouvement du point" ] => "motion",
      [ "svt", "L'absorption de l'eau par la plante verte" ] => "leaf",
      [ "svt", "La division méiotique" ] => "dna",
      [ "svt", "Le sang" ] => "body",
      [ "svt", "Les grands ensembles environnementaux" ] => "earth",
      [ "francais", "La dissertation littéraire" ] => "pen",
      [ "francais", "Le dialogue oral" ] => "speech",
      [ "francais", "Œuvre narrative" ] => "book",
      [ "histoire-geographie", "Histoire : l'ONU" ] => "hourglass",
      [ "histoire-geographie", "Le milieu physique en Côte d'Ivoire" ] => "map",
      [ "edhc", "Les droits humains" ] => "scales",
      [ "edhc", "Les organisations humanitaires" ] => "scales",
      [ "edhc", "Les principes fondamentaux" ] => "shield",
      [ "philosophie", "La connaissance de l'homme" ] => "thought",
      [ "philosophie", "Le commentaire de texte philosophique" ] => "pen"
    }.each do |(slug, name), key|
      assert_equal key, lesson_icon_key(material_slug: slug, name:), "#{slug} : #{name}"
    end
  end

  test "without a rule, or for an unknown subject, the icon of the subject is the fallback" do
    assert_nil lesson_icon_key(material_slug: "mathematiques", name: "Zzz")
    assert_nil lesson_icon_key(material_slug: "anglais", name: "Vecteurs")
    assert_includes lesson_icon(material_slug: "mathematiques", name: "Zzz"), "subjects/maths"
    assert_equal subject_illustration("mathematiques").tint, lesson_icon_tint(material_slug: "mathematiques", name: "Zzz")
    assert_includes lesson_icon(material_slug: "svt", name: "La cellule"), 'data-icon="dna"'
    assert_equal "bg-tint-pink", lesson_icon_tint(material_slug: "svt", name: "La cellule")
  end

  test "the lessons of the repository are covered by the rules" do
    files = Rails.root.glob("leçons/*/*/*.json")
    skip "no imported lesson here" if files.empty?
    misses = files.filter_map do |file|
      _, slug, name = File.basename(file, ".json").split("__")
      "#{slug} : #{name}" unless lesson_icon_key(material_slug: slug, name: name.tr("-", " "))
    end

    assert_empty misses
  end

  test "a short title cuts at the first « et », « ou », colon, dash or comma, keeping at least 4 letters" do
    assert_equal "Vecteurs", lesson_short_title("Vecteurs et points du plan")
    assert_equal "Équations", lesson_short_title("Équations et inéquations")
    assert_equal "Calcul littéral", lesson_short_title("Calcul littéral")
    assert_equal "Un et deux", lesson_short_title("Un et deux")
    assert_equal "La cellule", lesson_short_title("La cellule")
  end

  test "the number and the progression come from the subtitle" do
    assert_equal 3, lesson_number("Leçon 3 — progression DPFC 2026-2027")
    assert_equal 10, lesson_number("Leçon 10 · Progression DPFC 2026-2027")
    assert_nil lesson_number("Progression DPFC")
    assert_nil lesson_number(nil)
    assert_equal "Progression DPFC 2026-2027", lesson_progression("Leçon 3 — progression DPFC 2026-2027")
    assert_nil lesson_progression("Leçon 3")
  end
end
