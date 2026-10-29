require "test_helper"
require Rails.root.join("script/contenus/valider")

# CA-18 : le script de contrôle hors ligne refuse chaque faute de CA-3 à CA-9 avec la même raison que l'import,
# et accepte la leçon de la fabrique (test/support/factories/revision_sheet.rb).
class ContenusValiderTest < ActiveSupport::TestCase
  def check(document) = Contenus::Valider.new(document).call

  def course_of(document) = document["courses"].first

  def mutated
    document = Marshal.load(Marshal.dump(revision_sheet_document))
    yield course_of(document)
    document
  end

  def assert_refused(document, code, path_fragment = nil)
    result = check(document)
    found = result.reasons.any? { |path, reason| reason == code && (path_fragment.nil? || path.include?(path_fragment)) }
    assert found, "attendu #{code} (#{path_fragment}), obtenu #{result.reasons.inspect}"
  end

  test "accepte la leçon de la fabrique, sans avertissement de forme" do
    result = check(revision_sheet_document)
    assert_empty result.errors
    assert_empty result.reasons
  end

  test "refuse les formats v1 et v2 en format_retired" do
    [ 1, 2 ].each do |version|
      assert_refused revision_sheet_document.merge("version" => version), "format_retired"
    end
  end

  test "CA-3 : une notion sans exercice ou avec deux exercices, et le rapport la nomme" do
    assert_refused mutated { it["notions"][1].delete("exercise") }, "essential_exercise_count", "notions[1].exercise"
    two = mutated { it["notions"][0]["exercise"] = [ it["notions"][0]["exercise"], it["notions"][0]["exercise"] ] }
    assert_refused two, "essential_exercise_count", "notions[0].exercise"
  end

  test "CA-4 : trois ou cinq problèmes" do
    assert_refused mutated { it["exercises"].pop }, "lesson_exercise_count", "exercises"
    assert_refused mutated { it["exercises"] << it["exercises"].first }, "lesson_exercise_count", "exercises"
  end

  test "CA-5 : un exercice de 4 questions" do
    assert_refused mutated { it["notions"][0]["exercise"]["questions"].pop }, "too_few_questions", "notions[0].exercise.questions"
    assert_refused mutated { it["exercises"][2]["questions"].pop }, "too_few_questions", "exercises[2].questions"
  end

  test "CA-6 : une correction vide, trop courte ou trop longue" do
    assert_refused mutated { it["exercises"][0]["questions"][3]["explanation"] = " " }, "blank", "questions[3].explanation"
    assert_refused mutated { it["exercises"][0]["questions"][0].delete("explanation") }, "blank", "explanation"
    assert_refused mutated { it["exercises"][0]["questions"][0]["explanation"] = "Trop court." }, "too_short", "explanation"
    assert_refused mutated { it["exercises"][0]["questions"][0]["explanation"] = "a" * 2_001 }, "too_long", "explanation"
  end

  test "CA-7 : La méthode a 4 étapes et l'exemple corrigé 3" do
    document = mutated { it["notions"][0]["method"] << "Vérifier le résultat avec une calculatrice." }
    assert_refused document, "example_steps_mismatch", "notions[0].example.steps"
    assert_refused mutated { it["notions"][0]["method"] = [ "Une seule étape." ] }, "schema", "notions[0].method"
  end

  test "CA-8 : figure de sorte inconnue, paramètre hors bornes ou sans description" do
    assert_refused mutated { it["figures"][0]["kind"] = "hologram" }, "figure_invalid", "figures[0].kind"
    assert_refused mutated { it["figures"][0]["params"]["points"][0]["x"] = 99 }, "figure_invalid", "figures[0].params.points[0]"
    assert_refused mutated { it["figures"][0]["description"] = "" }, "figure_invalid", "figures[0].description"
    assert_refused mutated { it["figures"][0]["controls"] = [ { "param" => "height", "min" => 1, "max" => 5_000, "step" => 1, "label" => "h" } ]
                             it["figures"][0]["kind"] = "solid"; it["figures"][0]["params"] = { "shape" => "cone", "height" => 4, "radius" => 3 } }, "figure_invalid", "figures[0].controls[0].max"
  end

  test "CA-9 : un exercice ou une notion qui cite une figure absente" do
    assert_refused mutated { it["exercises"][0]["figure"] = "inconnue" }, "figure_missing", "exercises[0].figure"
    assert_refused mutated { it["notions"][1]["figure"] = "inconnue" }, "figure_missing", "notions[1].figure"
  end

  test "refuse un curseur qui ne règle pas une clé réglable présente dans params, avec la raison de l'import" do
    control = { "param" => "inconnu", "min" => 1, "max" => 9, "step" => 1, "label" => "x" }
    assert_refused mutated { it["figures"][0]["controls"] = [ control ] }, "figure_invalid", "figures[0].controls[0].param"
    assert_refused mutated { it["figures"][0]["controls"] = [ control.merge("param" => "points") ] }, "figure_invalid", "figures[0].controls[0].param"
    solid = { "key" => "cone", "kind" => "solid", "description" => "x" * 150, "params" => { "shape" => "cone", "height" => 4, "radius" => 3 },
              "controls" => [ { "param" => "height", "min" => 1, "max" => 9, "step" => 0.5, "label" => "hauteur" } ] }
    ok = check(mutated { it["figures"] << solid })
    assert_empty ok.errors
  end

  test "thème inconnu, notions en double, figures en double" do
    assert_refused mutated { it["theme"] = "pink" }, "schema", "theme"
    assert_refused mutated { it["notions"][1]["name"] = it["notions"][0]["name"] }, "invalid_value", "notions[1].name"
    assert_refused mutated { it["figures"] << it["figures"][0] }, "figure_invalid", "figures[1].key"
  end

  test "mêmes raisons que l'entité NotionSheet pour le gabarit, hors bornes de taille que le schéma refuse d'abord" do
    notion = revision_notion("Simplifier")
    notion["example"]["steps"] = [ "Un seul pas.", "Deux pas." ]
    notion["pitfall"] = "  "
    expected = Entities::Catalog::NotionSheet.errors_for(notion).map(&:last).uniq.sort
    assert_equal %w[blank example_steps_mismatch], expected

    document = mutated { it["notions"] = [ notion.merge("exercise" => revision_exercise("Exercice")) ] }
    assert_equal expected, check(document).reasons.map(&:last).uniq.sort
  end

  test "avertit si la correction d'une notion ne cite pas la méthode, et se tait si elle la cite" do
    silent = check(mutated { it["notions"][0]["exercise"]["questions"][0]["explanation"] = "On additionne : $2 + 2 = 4$, la réponse est 4." })
    assert_empty silent.errors
    assert(silent.warnings.any? { it.include?("notions[0].exercise.questions[0].explanation") && it.include?("La méthode") })

    by_number = check(mutated { it["notions"][0]["exercise"]["questions"][0]["explanation"] = "Étape 1 : on additionne $2 + 2 = 4$." })
    assert(by_number.warnings.none? { it.include?("notions[0].exercise.questions[0]") && it.include?("La méthode") })

    by_words = check(mutated { it["notions"][0]["exercise"]["questions"][0]["explanation"] = "On commence par décomposer le nombre en un carré parfait : $4 = 2 \\times 2$." })
    assert(by_words.warnings.none? { it.include?("notions[0].exercise.questions[0].explanation") && it.include?("La méthode") })
  end

  test "un problème de synthèse n'est pas soumis à l'avertissement de méthode" do
    result = check(revision_sheet_document)
    assert(result.warnings.none? { it.include?("exercises[") && it.include?("La méthode") })
  end

  test "avertit des mots interdits et des questions dépendantes, sans refuser" do
    result = check(mutated do
      it["exercises"][0]["questions"][0]["content"] = "Voir la figure ci-dessus : ce quiz est conforme au programme ?"
    end)
    assert_empty result.errors
    assert(result.warnings.any? { it.include?("vocabulaire interdit") })
    assert(result.warnings.any? { it.include?("dépend peut-être") })
  end
end
