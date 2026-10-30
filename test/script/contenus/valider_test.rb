require "test_helper"
require "open3"
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

  test "avertit d'une commande LaTeX coupée par un échappement JSON (\\neq écrit \\n + eq)" do
    document = mutated { |course| course["notions"][0]["pitfall"] = "On a $a \neq b$ et $\frac{1}{2}$." }

    warnings = check(document).warnings

    assert(warnings.any? { it.include?("notions[0].pitfall") && it.include?("LaTeX") }, warnings.inspect)
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

  # Les 30 questions de la fabrique (2 notions et 4 problèmes de 5) : les `count` premières deviennent `type`.
  def with_retyped(count, type)
    mutated do |course|
      all = course["notions"].flat_map { it["exercise"]["questions"] } + course["exercises"].flat_map { it["questions"] }
      all.first(count).each { |question| question.merge!("question_type" => type, "answers" => []) }
    end
  end

  def share_warnings(document) = check(document).warnings.grep(/part corrigée automatiquement/)

  test "avertit sous 50 % de questions corrigées automatiquement, au chemin du cours, avec le pourcentage arrondi" do
    warnings = share_warnings(with_retyped(16, "written"))

    assert_equal [ "courses[0] : part corrigée automatiquement : 47 % des questions (50 % au moins)" ], warnings
    assert_empty check(with_retyped(16, "written")).errors
  end

  test "pas d'avertissement à exactement 50 %, ni au-dessus" do
    assert_empty share_warnings(with_retyped(15, "written"))
    assert_empty share_warnings(revision_sheet_document)
  end

  test "un type inconnu n'est pas corrigé automatiquement ; le cahier et la rédaction non plus" do
    assert_equal 1, share_warnings(with_retyped(16, "oracle")).size
    assert_equal 1, share_warnings(with_retyped(16, "notebook")).size
  end

  test "l'avertissement de part se tait sans question" do
    assert_empty share_warnings(mutated { it["notions"] = [ { "name" => "x" } ]; it["exercises"] = [] })
  end

  test "les conseils de nombre de propositions ne visent que les types à choix" do
    advice = check(mutated { it["exercises"][0]["questions"][0]["answers"] = [ { "content" => "4", "correct" => true }, { "content" => "4" } ] }).warnings
    assert(advice.any? { it.include?("propositions conseillées") })
    assert(advice.any? { it.include?("deux propositions identiques") })

    written = check(with_retyped(1, "written")).warnings
    assert(written.none? { it.include?("notions[0].exercise.questions[0].answers") })
  end

  test "Vrai/Faux : avertit quand les propositions ne sont pas Vrai et Faux" do
    document = mutated { it["exercises"][0]["questions"][0].merge!("question_type" => "true_false") }
    assert(check(document).warnings.any? { it.include?("Vrai/Faux") })
  end

  def schema_paths(document) = check(document).reasons.select { |_, code| code == "schema" }.map(&:first)

  test "refuse en schema chaque forme que le schéma refuse, au chemin de la faute" do
    {
      "courses" => [ ->(d) { d["courses"] = {} }, "courses" ],
      "cours" => [ ->(d) { d["courses"] = [ 3 ] }, "courses[0]" ],
      "notions" => [ ->(d) { course_of(d)["notions"] = "x" }, "courses[0].notions" ],
      "exercises" => [ ->(d) { course_of(d)["exercises"] = "x" }, "courses[0].exercises" ],
      "notion" => [ ->(d) { course_of(d)["notions"][0] = 3 }, "courses[0].notions[0]" ],
      "exercice" => [ ->(d) { course_of(d)["exercises"][0] = 3 }, "courses[0].exercises[0]" ],
      "énoncé d'exercice" => [ ->(d) { course_of(d)["exercises"][0]["statement"] = 3 }, "courses[0].exercises[0].statement" ],
      "type d'exercice" => [ ->(d) { course_of(d)["exercises"][0]["exercise_type"] = 3 }, "courses[0].exercises[0].exercise_type" ],
      "questions" => [ ->(d) { course_of(d)["exercises"][0]["questions"] = "x" }, "courses[0].exercises[0].questions" ],
      "question" => [ ->(d) { course_of(d)["exercises"][0]["questions"][0] = 3 }, "courses[0].exercises[0].questions[0]" ],
      "propositions" => [ ->(d) { course_of(d)["exercises"][0]["questions"][0]["answers"] = "x" }, "courses[0].exercises[0].questions[0].answers" ],
      "explication" => [ ->(d) { course_of(d)["exercises"][0]["questions"][0]["explanation"] = 3 }, "courses[0].exercises[0].questions[0].explanation" ],
      "nom en nombre" => [ ->(d) { course_of(d)["name"] = 3 }, "courses[0].name" ],
      "figure mal formée" => [ ->(d) { course_of(d)["figures"] = [ 3 ] }, "courses[0].figures[0]" ]
    }.each do |label, (mutation, path)|
      document = Marshal.load(Marshal.dump(revision_sheet_document))
      mutation.call(document)
      assert_includes schema_paths(document), path, label
    end
  end

  test "lit les figures absentes, les clés de figure non textuelles et les notions sans nom" do
    assert_empty check(mutated { it.delete("figures"); it["notions"].each { |n| n["figure"] = nil; n["exercise"]["figure"] = nil } }).errors
    assert_includes check(mutated { it["figures"] << { "key" => 3, "kind" => "geometry", "description" => "d", "params" => {} } }).reasons.map(&:last), "schema"
    assert_includes check(mutated { it["notions"][0]["name"] = "" }).reasons.map(&:last), "schema"
    assert_includes check(mutated { it["notions"][0]["name"] = " " }).reasons.map(&:last), "blank"
  end

  test "avertit du sous-titre, du fichier à plusieurs cours et du placement hors règle" do
    assert(check(mutated { it["subtitle"] = "Autre" }).warnings.any? { it.include?("subtitle") && it.include?("Leçon N") })
    assert(check(mutated { it["subtitle"] = "Leçon 3 — progression DPFC 2026-2027" }).warnings.none? { it.include?("subtitle") })
    assert(check(mutated { it["series_name"] = "A" }).warnings.any? { it.include?("1er cycle") })
    assert(check(mutated { it["level_name"] = "2nde" }).warnings.any? { it.include?("série attendue") })
    assert(check(mutated { it["material_name"] = "EDHC"; it["level_name"] = "Tle" }).warnings.any? { it.include?("EDHC") })
    assert(check(mutated { it["material_name"] = "Philosophie" }).warnings.any? { it.include?("Philosophie") })
    two = revision_sheet_document.tap { it["courses"] << it["courses"][0] }
    assert(check(two).warnings.any? { it.include?("un fichier = un cours") })
  end

  test "avertit d'un énoncé répété, de HTML, de \\ce et de formules dans un champ sans rendu" do
    result = check(mutated do
      it["exercises"][0]["questions"][1]["content"] = it["exercises"][0]["questions"][0]["content"]
      it["notions"][0]["pitfall"] = "Voir <b>gras</b> et \\ce{H2O} dans le texte du piège."
      it["name"] = "Racines $x$"
    end)
    assert(result.warnings.any? { it.include?("énoncé répété") })
    assert(result.warnings.any? { it.include?("pas de HTML") })
    assert(result.warnings.any? { it.include?("ce{") })
    assert(result.warnings.any? { it.include?("pas de formule") })
  end

  test "la ligne de commande rend 0 sans erreur, 1 avec une erreur ou un fichier illisible" do
    dir = Dir.mktmpdir
    good = File.join(dir, "bonne.json")
    bad = File.join(dir, "mauvaise.json")
    File.write(good, revision_sheet_document.to_json)
    File.write(bad, mutated { it["exercises"].pop; it["exercises"][0]["questions"] = Array.new(31) { revision_question(it + 1) } }.to_json)
    out = StringIO.new

    assert_equal 0, Contenus::Valider.run([ good ], out:)
    assert_equal 1, Contenus::Valider.run([ good, bad, File.join(dir, "absent.json") ], out:)
    assert_includes out.string, "✓ #{good}"
    assert_includes out.string, "ERREUR"
    assert_includes out.string, "JSON illisible"

    many = File.join(dir, "beaucoup.json")
    File.write(many, mutated { it["exercises"][0]["questions"] = Array.new(40) { revision_question(1).merge("answers" => []) } }.to_json)
    assert_equal 1, Contenus::Valider.run([ many ], out:)
    assert_includes out.string, "autres erreurs"
    assert_raises(SystemExit) { Contenus::Valider.run([], out:) }
  ensure
    FileUtils.rm_rf(dir)
  end

  test "lancé comme programme, le fichier sort avec le code de la ligne de commande" do
    script = Rails.root.join("script/contenus/valider.rb").to_s
    Dir.mktmpdir do |dir|
      good = File.join(dir, "bonne.json")
      File.write(good, revision_sheet_document.to_json)
      output, status = Open3.capture2e("ruby", script, good, File.join(dir, "absent.json"))

      assert_equal 1, status.exitstatus
      assert_includes output, "✓ #{good}"
      assert_equal 0, Open3.capture2e("ruby", script, good).last.exitstatus
    end
  end
end
