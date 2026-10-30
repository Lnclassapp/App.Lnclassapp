require "test_helper"
require Rails.root.join("script/contenus/valider")

# CA-18 : le script de contrôle sort en erreur en nommant LA MÊME règle que l'import. Pour chaque faute, l'import réel (schéma puis
# adaptateur, comme le téléversement) et le script rendent le même ensemble de [chemin, raison].
class ContenusPariteImportTest < ActiveSupport::TestCase
  setup do
    seed_referential
    @author = create_team_member(team_role: "content", second_factor: false)
  end

  def adapter
    UseCases::Catalog::ImportCourseTree.new(courses: Repositories::Catalog::CourseRepository.new, essentials: Repositories::Catalog::EssentialRepository.new,
                                            taxonomy: Repositories::Catalog::TaxonomyRepository.new, writer: Repositories::Catalog::ContentTreeWriter.new)
  end

  def import_pairs(document)
    report = create_import_report(kind: "course_tree", imported_by: @author)
    files = [ import_upload(io: StringIO.new(document.to_json), filename: "lecon.json") ]
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id, files:)
    UseCases::Catalog::RunImport.new(
      adapter:, reports: Repositories::Catalog::ImportReportRepository.new, files: Repositories::Catalog::ImportFileStore.new,
      schema: Repositories::Catalog::ImportSchemaValidator.new, users: Repositories::Identity::UserRepository.new,
      audit_log: Repositories::Identity::AuditLogRepository.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)
    report.reload.import_errors.map { it.values_at("path", "code").then { |path, code| [ path.delete_prefix("courses[0]."), code ] } }.uniq.sort
  end

  def script_pairs(document)
    Contenus::Valider.new(document).call.reasons.map { |path, code| [ path.delete_prefix("courses[0]."), code ] }.uniq.sort
  end

  def mutated(&block)
    document = Marshal.load(Marshal.dump(revision_sheet_document))
    instance_exec(document["courses"].first, &block)
    document
  end

  def assert_parity(label, document, expected_code = nil)
    from_import = import_pairs(document)
    refute_empty from_import, "#{label} : l'import devrait refuser"
    assert_equal from_import, script_pairs(document), "#{label} : le script doit rendre les mêmes raisons que l'import"
    assert_includes from_import.map(&:last), expected_code, label if expected_code
  end

  # Une figure d'une sorte nouvelle qui remplace la figure 0 (la leçon la cite : on garde sa clé).
  def figure_of(kind, params) = revision_figure.merge("kind" => kind, "params" => params)

  MAP_PARAMS = { "base" => "cote_d_ivoire", "legend" => %w[Forêt Savane],
                 "areas" => [ { "id" => "dense_forest", "category" => 1 }, { "id" => "savanna", "category" => 2 } ],
                 "places" => [ { "id" => "abidjan", "label" => "Capitale" } ], "routes" => [ { "from" => "abidjan", "to" => "man" } ] }.freeze
  TIMELINE_PARAMS = { "start" => 1880, "end" => 1960, "step" => 10, "events" => [ { "at" => 1893, "label" => "Colonie" } ] }.freeze
  TREE_PARAMS = { "layout" => "tree", "nodes" => %w[r a b].map { { "id" => it, "label" => it } }, "edges" => [ { "from" => "r", "to" => "a" }, { "from" => "r", "to" => "b" } ] }.freeze

  LENS_PARAMS = { "mode" => "lens", "lens" => "convergent", "focal" => 4, "object_distance" => 12, "object_height" => 2 }.freeze
  ALKANE_PARAMS = { "mode" => "alkane", "carbons" => 3, "display" => "developed" }.freeze
  WATER_PARAMS = { "mode" => "custom",
                   "atoms" => [ { "id" => "o", "element" => "O", "x" => 6, "y" => 6 }, { "id" => "a", "element" => "H", "x" => 3, "y" => 8 },
                                { "id" => "b", "element" => "H", "x" => 9, "y" => 8 } ],
                   "bonds" => [ [ "o", "a", 1 ], [ "o", "b", 1 ] ] }.freeze

  def explanation(document_course, value) = (document_course["exercises"][0]["questions"][0]["explanation"] = value)

  test "la leçon de la fabrique : ni l'import ni le script ne refusent" do
    assert_empty import_pairs(revision_sheet_document)
    assert_empty script_pairs(revision_sheet_document)
  end

  test "une carte bien formée passe l'import et le script" do
    document = mutated { it["figures"][0] = figure_of("map", MAP_PARAMS) }

    assert_empty import_pairs(document)
    assert_empty script_pairs(document)
  end

  test "un tracé optique et une molécule bien formés passent l'import et le script" do
    [ figure_of("optics", LENS_PARAMS), figure_of("optics", { "mode" => "eye", "defect" => "myopia", "correction" => "divergent" }),
      figure_of("molecule", ALKANE_PARAMS), figure_of("molecule", WATER_PARAMS) ].each do |figure|
      document = mutated { it["figures"][0] = figure }

      assert_empty import_pairs(document), figure["kind"]
      assert_empty script_pairs(document), figure["kind"]
    end
  end

  test "parité : version retirée, version inconnue, autre format" do
    [ [ 2, "format_retired" ], [ 4, "version_unsupported" ] ].each do |version, code|
      assert_parity("version #{version}", revision_sheet_document.merge("version" => version), code)
    end
    assert_parity("autre format", revision_sheet_document.merge("format" => "lnclass.autre"), "format_mismatch")
  end

  CASES = {
    "schéma : méthode absente" => [ ->(c) { c["notions"][0].delete("method") }, "schema" ],
    "schéma : étapes de l'exemple absentes" => [ ->(c) { c["notions"][0]["example"].delete("steps") }, "schema" ],
    "schéma : figures n'est pas une liste" => [ ->(c) { c["figures"] = {} }, "schema" ],
    "CA-3 notion sans exercice" => [ ->(c) { c["notions"][1].delete("exercise") }, "essential_exercise_count" ],
    "CA-3 notion avec exercice null" => [ ->(c) { c["notions"][1]["exercise"] = nil }, "essential_exercise_count" ],
    "CA-3 notion avec deux exercices" => [ ->(c) { c["notions"][0]["exercise"] = [ c["notions"][0]["exercise"], c["notions"][0]["exercise"] ] }, "essential_exercise_count" ],
    "CA-4 trois problèmes" => [ ->(c) { c["exercises"].pop }, "lesson_exercise_count" ],
    "CA-4 cinq problèmes" => [ ->(c) { c["exercises"] << c["exercises"].first }, "lesson_exercise_count" ],
    "CA-5 quatre questions (notion)" => [ ->(c) { c["notions"][0]["exercise"]["questions"].pop }, "too_few_questions" ],
    "CA-5 quatre questions (problème)" => [ ->(c) { c["exercises"][2]["questions"].pop }, "too_few_questions" ],
    "CA-5 aucune question" => [ ->(c) { c["exercises"][2]["questions"] = [] }, "too_few_questions" ],
    "CA-5 clé questions absente" => [ ->(c) { c["exercises"][2].delete("questions") }, "too_few_questions" ],
    "CA-5 trente et une questions" => [ ->(c) { c["exercises"][1]["questions"] = Array.new(31) { revision_question(it + 1) } }, "invalid_count" ],
    "CA-6 correction vide" => [ ->(c) { c["exercises"][0]["questions"][3]["explanation"] = " " }, "blank" ],
    "CA-6 correction absente" => [ ->(c) { c["notions"][0]["exercise"]["questions"][1].delete("explanation") }, "blank" ],
    "CA-6 correction trop courte" => [ ->(c) { c["exercises"][0]["questions"][0]["explanation"] = "Trop court." }, "too_short" ],
    "CA-6 correction trop longue" => [ ->(c) { c["exercises"][0]["questions"][0]["explanation"] = "a" * 2_001 }, "too_long" ],
    "CA-7 méthode à 4 étapes, exemple à 3" => [ ->(c) { c["notions"][0]["method"] << "Vérifier le résultat." }, "example_steps_mismatch" ],
    "CA-7 méthode à une étape" => [ ->(c) { c["notions"][0]["method"] = [ "Une seule." ] }, "schema" ],
    "CA-7 exemple à une étape" => [ ->(c) { c["notions"][0]["example"]["steps"] = [ "Une seule." ] }, "schema" ],
    "CA-7 neuf étapes" => [ ->(c) { c["notions"][0]["method"] = Array.new(9) { "Étape #{it}" } }, "schema" ],
    "gabarit : rappel trop long" => [ ->(c) { c["notions"][0]["remember"] = "a" * 1_201 }, "schema" ],
    "gabarit : piège fait d'espaces" => [ ->(c) { c["notions"][0]["pitfall"] = "  " }, "blank" ],
    "gabarit : étape trop longue" => [ ->(c) { c["notions"][0]["method"][0] = "a" * 301 }, "schema" ],
    "gabarit : énoncé de l'exemple absent" => [ ->(c) { c["notions"][0]["example"].delete("statement") }, "schema" ],
    "nom de leçon fait d'espaces" => [ ->(c) { c["name"] = "   " }, "blank" ],
    "sous-titre de 200 caractères" => [ ->(c) { c["subtitle"] = "a" * 200 }, "too_long" ],
    "nom de notion de 160 caractères" => [ ->(c) { c["notions"][0]["name"] = "a" * 160 }, "too_long" ],
    "titre d'exercice de 160 caractères" => [ ->(c) { c["exercises"][0]["title"] = "a" * 160 }, "too_long" ],
    "proposition vide" => [ ->(c) { c["exercises"][0]["questions"][0]["answers"][0]["content"] = " " }, "blank" ],
    "onze propositions" => [ ->(c) { c["exercises"][0]["questions"][0]["answers"] = Array.new(11) { { "content" => "r#{it}", "correct" => it.zero? } } }, "schema" ],
    "treize figures" => [ ->(c) { c["figures"] = Array.new(13) { revision_figure(key: "f#{it}") } }, "schema" ],
    "figure citée au format invalide" => [ ->(c) { c["exercises"][0]["figure"] = "Mauvaise Clé" }, "schema" ],
    "plusieurs fautes de l'adaptateur à la fois" => [ ->(c) { c["exercises"].pop; c["notions"][0].delete("exercise"); c["level_name"] = "7ème" }, nil ],
    "une faute du schéma masque celles de l'adaptateur" => [ ->(c) { c["theme"] = "pink"; c["exercises"].pop }, "schema" ],
    "CA-8 figure de sorte inconnue" => [ ->(c) { c["figures"][0]["kind"] = "hologram" }, nil ],
    "CA-8 paramètre hors bornes" => [ ->(c) { c["figures"][0]["params"]["points"][0]["x"] = 99 }, "figure_invalid" ],
    "CA-8 figure sans description" => [ ->(c) { c["figures"][0]["description"] = "" }, nil ],
    "frise dont un événement est avant start" => [ ->(c) { c["figures"][0] = figure_of("timeline", TIMELINE_PARAMS.merge("events" => [ { "at" => 1850, "label" => "Avant" } ])) }, "figure_invalid" ],
    "carte dont un lieu n'est pas dans le fond" => [ ->(c) { c["figures"][0] = figure_of("map", MAP_PARAMS.merge("places" => [ { "id" => "paris" } ])) }, "figure_invalid" ],
    "schéma tree à deux racines" => [ ->(c) { c["figures"][0] = figure_of("diagram", TREE_PARAMS.merge("edges" => [ { "from" => "r", "to" => "a" } ])) }, "figure_invalid" ],
    "aire de carte au-delà de la légende" => [ ->(c) { c["figures"][0] = figure_of("map", MAP_PARAMS.merge("areas" => [ { "id" => "savanna", "category" => 3 } ])) }, "figure_invalid" ],
    "route d'un lieu à lui-même" => [ ->(c) { c["figures"][0] = figure_of("map", MAP_PARAMS.merge("base" => "africa", "areas" => [], "routes" => [ { "from" => "dakar", "to" => "dakar" } ])) }, "figure_invalid" ],
    "frise de 401 unités au pas 2" => [ ->(c) { c["figures"][0] = figure_of("timeline", TIMELINE_PARAMS.merge("start" => 0, "end" => 401, "step" => 2, "events" => [])) }, "figure_invalid" ],
    "légende de carte faite d'un nombre" => [ ->(c) { c["figures"][0] = figure_of("map", MAP_PARAMS.merge("legend" => [ 3, "Savane" ])) }, "figure_invalid" ],
    "curseur de frise dont le max atteint end" => [ ->(c) { c["figures"][0] = figure_of("timeline", TIMELINE_PARAMS).merge("controls" => [ { "param" => "start", "min" => 1850, "max" => 1960, "step" => 5, "label" => "début" } ]) }, "figure_invalid" ],
    "lentille sans focale" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.except("focal")) }, "figure_invalid" ],
    "lentille sans nature" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.except("lens")) }, "figure_invalid" ],
    "lentille sans distance d'objet" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.except("object_distance")) }, "figure_invalid" ],
    "lentille sans hauteur d'objet" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.except("object_height")) }, "figure_invalid" ],
    "œil sans défaut" => [ ->(c) { c["figures"][0] = figure_of("optics", { "mode" => "eye" }) }, "figure_invalid" ],
    "correction d'une lentille" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.merge("correction" => "divergent")) }, "figure_invalid" ],
    "tracé optique sans mode" => [ ->(c) { c["figures"][0] = figure_of("optics", LENS_PARAMS.except("mode")) }, "figure_invalid" ],
    "alcane sans carbones" => [ ->(c) { c["figures"][0] = figure_of("molecule", ALKANE_PARAMS.except("carbons")) }, "figure_invalid" ],
    "alcane sans affichage" => [ ->(c) { c["figures"][0] = figure_of("molecule", ALKANE_PARAMS.except("display")) }, "figure_invalid" ],
    "alcane de 2,5 carbones" => [ ->(c) { c["figures"][0] = figure_of("molecule", ALKANE_PARAMS.merge("carbons" => 2.5)) }, "figure_invalid" ],
    "molécule libre sans atomes" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.except("atoms")) }, "figure_invalid" ],
    "molécule libre sans liaisons" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.except("bonds")) }, "figure_invalid" ],
    "atome d'identifiant dupliqué" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("atoms" => WATER_PARAMS["atoms"].map { it.merge("id" => "o") })) }, "figure_invalid" ],
    "liaison vers un atome absent" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("bonds" => [ [ "o", "z", 1 ] ])) }, "figure_invalid" ],
    "liaison d'ordre 4" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("bonds" => [ [ "o", "a", 4 ] ])) }, "figure_invalid" ],
    "élément inconnu" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("atoms" => [ { "id" => "o", "element" => "Xe", "x" => 6, "y" => 6 } ] + WATER_PARAMS["atoms"].drop(1))) }, "figure_invalid" ],
    "atome hors de la grille" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("atoms" => [ { "id" => "o", "element" => "O", "x" => 13, "y" => 6 } ] + WATER_PARAMS["atoms"].drop(1))) }, "figure_invalid" ],
    "valence de l'oxygène dépassée" => [ ->(c) { c["figures"][0] = figure_of("molecule", WATER_PARAMS.merge("bonds" => [ [ "o", "a", 1 ], [ "o", "b", 2 ] ])) }, "figure_invalid" ],
    "CA-9 problème qui cite une figure absente" => [ ->(c) { c["exercises"][0]["figure"] = "inconnue" }, "figure_missing" ],
    "CA-9 notion qui cite une figure absente" => [ ->(c) { c["notions"][1]["figure"] = "inconnue" }, "figure_missing" ],
    "type de question inconnu" => [ ->(c) { c["exercises"][0]["questions"][0]["question_type"] = "oracle" }, "invalid_value" ],
    "deux notions de même nom" => [ ->(c) { c["notions"][1]["name"] = c["notions"][0]["name"] }, "invalid_value" ],
    "deux figures de même clé" => [ ->(c) { c["figures"] << c["figures"][0] }, "figure_invalid" ],
    "thème inconnu" => [ ->(c) { c["theme"] = "pink" }, "schema" ],
    "niveau inconnu" => [ ->(c) { c["level_name"] = "7ème" }, "unknown_level" ],
    "matière inconnue" => [ ->(c) { c["material_name"] = "Magie" }, "unknown_material" ],
    "type d'exercice inconnu" => [ ->(c) { c["exercises"][0]["exercise_type"] = "examen" }, "invalid_value" ],
    "énoncé d'exercice vide" => [ ->(c) { c["exercises"][0]["statement"] = " " }, nil ],
    "aucune notion" => [ ->(c) { c["notions"] = [] }, "schema" ],
    "treize notions" => [ ->(c) { c["notions"] = Array.new(13) { revision_notion("Notion #{it}") } }, "schema" ],
    "proposition correcte en trop" => [ ->(c) { c["exercises"][0]["questions"][0]["answers"].each { it["correct"] = true } }, "question_structure" ],
    "énoncé de question trop long" => [ ->(c) { c["exercises"][0]["questions"][0]["content"] = "a" * 2_001 }, nil ]
  }.freeze

  CASES.each do |label, (mutation, code)|
    test "parité : #{label}" do
      assert_parity(label, mutated(&mutation), code)
    end
  end

  EXPLANATION = "Corrigé modèle : on répond en citant le texte, puis on justifie la réponse."

  SAMPLES = {
    "written" => { "content" => "Explique en deux phrases pourquoi le narrateur hésite.", "question_type" => "written", "explanation" => EXPLANATION,
                   "points" => 4, "starter" => "Le narrateur hésite parce que", "criteria" => [ "Cite le texte", "Justifie la réponse" ], "answers" => [] },
    "notebook" => { "content" => "Recopie la leçon dans ton cahier.", "question_type" => "notebook", "explanation" => EXPLANATION, "answers" => [] },
    "matching" => { "content" => "Relie chaque auteur à son œuvre.", "question_type" => "matching", "explanation" => EXPLANATION,
                    "answers" => [ { "content" => "Hugo", "match" => "Les Misérables" }, { "content" => "Molière", "match" => "Le Misanthrope" },
                                   { "content" => "Camus", "match" => "L'Étranger" } ] },
    "ordering" => { "content" => "Remets les étapes dans l'ordre.", "question_type" => "ordering", "explanation" => EXPLANATION,
                    "answers" => [ { "content" => "Lire" }, { "content" => "Souligner" }, { "content" => "Répondre" } ] },
    "fill_blank" => { "content" => "Le héros s'appelle ___.", "question_type" => "fill_blank", "explanation" => EXPLANATION,
                      "answers" => [ { "content" => "Ulysse" }, { "content" => "Ulysse le Rusé" } ] },
    "numeric" => { "content" => "Combien mesure le segment ?", "question_type" => "numeric", "explanation" => EXPLANATION, "tolerance" => 0.5,
                   "unit" => "cm", "answers" => [ { "content" => "4,5" } ] },
    "select" => { "content" => "Le mot ___ est un nom.", "question_type" => "select", "explanation" => EXPLANATION,
                  "answers" => [ { "content" => "maison", "correct" => true }, { "content" => "courir", "correct" => false } ] },
    "true_false" => { "content" => "Le narrateur est le héros.", "question_type" => "true_false", "explanation" => EXPLANATION,
                      "answers" => [ { "content" => "Vrai", "correct" => true }, { "content" => "Faux", "correct" => false } ] },
    "multiple_correct_2" => { "content" => "Quels mots sont des noms ?", "question_type" => "multiple_correct_2", "explanation" => EXPLANATION,
                              "answers" => [ { "content" => "maison", "correct" => true }, { "content" => "école", "correct" => true },
                                             { "content" => "courir", "correct" => false } ] },
    "multiple_correct_3" => { "content" => "Quels mots sont des verbes ?", "question_type" => "multiple_correct_3", "explanation" => EXPLANATION,
                              "answers" => [ { "content" => "courir", "correct" => true }, { "content" => "lire", "correct" => true },
                                             { "content" => "chanter", "correct" => true }, { "content" => "maison", "correct" => false } ] },
    "single_choice" => nil
  }.freeze

  def sample(type) = Marshal.load(Marshal.dump(SAMPLES[type] || revision_question))

  def with_question(type, &block)
    mutated do |course|
      question = sample(type)
      block&.call(question)
      course["exercises"][0]["questions"][0] = question
    end
  end

  test "parité : chaque type de question bien formé, aucune erreur des deux côtés" do
    questions = SAMPLES.keys.map { sample(it) } + [ sample("written").merge("points" => 0.5), sample("written").merge("points" => 20),
                                                    sample("written").merge("points" => nil, "unit" => nil, "starter" => nil, "criteria" => nil, "tolerance" => nil),
                                                    sample("single_choice").merge("points" => 2.5),
                                                    sample("written").merge("image" => { "description" => "Un schéma du texte" }),
                                                    sample("written").merge("image" => { "description" => "a" * 150 }) ]
    document = mutated { it["exercises"][0]["questions"] = questions }
    assert_empty import_pairs(document)
    assert_empty script_pairs(document)
  end

  test "une question written avec points, criteria, starter et answers vides passe le script, comme l'import" do
    document = with_question("written")
    assert_empty import_pairs(document)
    assert_empty Contenus::Valider.new(document).call.errors
  end

  QUESTION_CASES = {
    "multiple_correct_3 à deux bonnes réponses" => [ "multiple_correct_3", ->(q) { q["answers"][2]["correct"] = false }, "question_structure" ],
    "written sans explication" => [ "written", ->(q) { q.delete("explanation") }, "question_structure" ],
    "written à explication vide" => [ "written", ->(q) { q["explanation"] = " " }, "question_structure" ],
    "notebook sans explication" => [ "notebook", ->(q) { q.delete("explanation") }, "question_structure" ],
    "notebook avec propositions" => [ "notebook", ->(q) { q["answers"] = [ { "content" => "a" } ] }, "question_structure" ],
    "written avec propositions" => [ "written", ->(q) { q["answers"] = [ { "content" => "a", "correct" => true }, { "content" => "b" } ] }, "question_structure" ],
    "written : points 25" => [ "written", ->(q) { q["points"] = 25 }, "schema" ],
    "written : points 0,3" => [ "written", ->(q) { q["points"] = 0.3 }, "schema" ],
    "written : points 1,25" => [ "written", ->(q) { q["points"] = 1.25 }, "schema" ],
    "written : points 0" => [ "written", ->(q) { q["points"] = 0 }, "schema" ],
    "written : points en texte" => [ "written", ->(q) { q["points"] = "3" }, "schema" ],
    "written : starter de 151 caractères" => [ "written", ->(q) { q["starter"] = "a" * 151 }, "schema" ],
    "written : starter qui n'est pas un texte" => [ "written", ->(q) { q["starter"] = 3 }, "schema" ],
    "written : neuf critères" => [ "written", ->(q) { q["criteria"] = Array.new(9) { "c#{it}" } }, "schema" ],
    "written : critère de 151 caractères" => [ "written", ->(q) { q["criteria"] = [ "a" * 151 ] }, "schema" ],
    "written : critère qui n'est pas un texte" => [ "written", ->(q) { q["criteria"] = [ 1 ] }, "schema" ],
    "written : criteria n'est pas une liste" => [ "written", ->(q) { q["criteria"] = "Cite le texte" }, "schema" ],
    "written : critère fait d'espaces" => [ "written", ->(q) { q["criteria"] = [ "Cite", " " ] }, "question_structure" ],
    "written : unit" => [ "written", ->(q) { q["unit"] = "cm" }, "question_structure" ],
    "written : tolerance" => [ "written", ->(q) { q["tolerance"] = 1 }, "question_structure" ],
    "written : propositions avec match" => [ "written", ->(q) { q["answers"] = [ { "content" => "a", "match" => "b" } ] }, "question_structure" ],
    "single_choice : criteria" => [ "single_choice", ->(q) { q["criteria"] = [ "Cite" ] }, "question_structure" ],
    "single_choice : starter" => [ "single_choice", ->(q) { q["starter"] = "Parce que" }, "question_structure" ],
    "single_choice : unit" => [ "single_choice", ->(q) { q["unit"] = "cm" }, "question_structure" ],
    "single_choice : tolerance" => [ "single_choice", ->(q) { q["tolerance"] = 0.5 }, "question_structure" ],
    "single_choice : match" => [ "single_choice", ->(q) { q["answers"][0]["match"] = "x" }, "question_structure" ],
    "single_choice : match vide" => [ "single_choice", ->(q) { q["answers"][0]["match"] = "" }, "question_structure" ],
    "single_choice : une seule proposition" => [ "single_choice", ->(q) { q["answers"].pop }, "question_structure" ],
    "single_choice : proposition au format ancien is_correct" => [ "single_choice", ->(q) { q["answers"].each { it.delete("correct"); it["is_correct"] = true } }, "question_structure" ],
    "single_choice : correct n'est pas un booléen" => [ "single_choice", ->(q) { q["answers"][0]["correct"] = "oui" }, "schema" ],
    "single_choice : clé inconnue sur la proposition" => [ "single_choice", ->(q) { q["answers"][0]["is_right"] = true }, "schema" ],
    "single_choice : clé inconnue sur la question" => [ "single_choice", ->(q) { q["criterias"] = [ "Cite" ] }, "schema" ],
    "single_choice : propositions en texte" => [ "single_choice", ->(q) { q["answers"] = [ "a", "b" ] }, "schema" ],
    "single_choice : match en nombre" => [ "single_choice", ->(q) { q["answers"][0]["match"] = 4 }, "schema" ],
    "single_choice : proposition de contenu nombre" => [ "single_choice", ->(q) { q["answers"][0]["content"] = 4 }, "schema" ],
    "true_false : trois propositions" => [ "single_choice", ->(q) { q["question_type"] = "true_false"; q["answers"] << { "content" => "c" } }, "question_structure" ],
    "multiple_correct_2 : une seule bonne" => [ "single_choice", ->(q) { q["question_type"] = "multiple_correct_2"; q["answers"] += [ { "content" => "c" }, { "content" => "d" } ] }, "question_structure" ],
    "type inconnu" => [ "single_choice", ->(q) { q["question_type"] = "oracle" }, "invalid_value" ],
    "type inconnu avec tolerance" => [ "single_choice", ->(q) { q["question_type"] = "oracle"; q["tolerance"] = 1 }, "invalid_value" ],
    "type qui n'est pas un texte" => [ "single_choice", ->(q) { q["question_type"] = 3 }, "schema" ],
    "matching : aucune paire" => [ "matching", ->(q) { q["answers"] = [] }, "question_structure" ],
    "matching : six paires" => [ "matching", ->(q) { q["answers"] += Array.new(3) { { "content" => "g#{it}", "match" => "d#{it}" } } }, "question_structure" ],
    "matching : côté droit manquant" => [ "matching", ->(q) { q["answers"][0].delete("match") }, "question_structure" ],
    "matching : côtés droits identiques" => [ "matching", ->(q) { q["answers"][0]["match"] = q["answers"][1]["match"] }, "question_structure" ],
    "matching : côtés gauches identiques" => [ "matching", ->(q) { q["answers"][0]["content"] = q["answers"][1]["content"] }, "question_structure" ],
    "matching : tolerance" => [ "matching", ->(q) { q["tolerance"] = 1 }, "question_structure" ],
    "ordering : deux étapes" => [ "ordering", ->(q) { q["answers"].pop }, "question_structure" ],
    "ordering : sept étapes" => [ "ordering", ->(q) { q["answers"] += Array.new(4) { { "content" => "s#{it}" } } }, "question_structure" ],
    "ordering : étapes identiques" => [ "ordering", ->(q) { q["answers"][0]["content"] = "  SOULIGNER " }, "question_structure" ],
    "ordering : match" => [ "ordering", ->(q) { q["answers"][0]["match"] = "x" }, "question_structure" ],
    "fill_blank : sans trou" => [ "fill_blank", ->(q) { q["content"] = "Le héros s'appelle." }, "question_structure" ],
    "fill_blank : deux trous" => [ "fill_blank", ->(q) { q["content"] = "___ et ___." }, "question_structure" ],
    "fill_blank : aucune réponse acceptée" => [ "fill_blank", ->(q) { q["answers"] = [] }, "question_structure" ],
    "fill_blank : six réponses acceptées" => [ "fill_blank", ->(q) { q["answers"] = Array.new(6) { { "content" => "r#{it}" } } }, "question_structure" ],
    "fill_blank : réponses identiques" => [ "fill_blank", ->(q) { q["answers"] = [ { "content" => "Éole" }, { "content" => "eole" } ] }, "question_structure" ],
    "fill_blank : réponse vide" => [ "fill_blank", ->(q) { q["answers"][1]["content"] = " " }, "blank" ],
    "numeric : deux valeurs" => [ "numeric", ->(q) { q["answers"] << { "content" => "5" } }, "question_structure" ],
    "numeric : aucune valeur" => [ "numeric", ->(q) { q["answers"] = [] }, "question_structure" ],
    "numeric : valeur illisible" => [ "numeric", ->(q) { q["answers"][0]["content"] = "beaucoup" }, "question_structure" ],
    "numeric : tolerance à cinq décimales" => [ "numeric", ->(q) { q["tolerance"] = 0.00001 }, "question_structure" ],
    "numeric : tolerance négative" => [ "numeric", ->(q) { q["tolerance"] = -1 }, "schema" ],
    "numeric : tolerance trop grande" => [ "numeric", ->(q) { q["tolerance"] = 1e9 }, "schema" ],
    "numeric : tolerance en texte" => [ "numeric", ->(q) { q["tolerance"] = "0,5" }, "schema" ],
    "numeric : unit de 11 caractères" => [ "numeric", ->(q) { q["unit"] = "a" * 11 }, "schema" ],
    "numeric : unit avec un chiffre" => [ "numeric", ->(q) { q["unit"] = "cm2" }, "question_structure" ],
    "numeric : unit qui n'est pas un texte" => [ "numeric", ->(q) { q["unit"] = 2 }, "schema" ],
    "numeric : criteria" => [ "numeric", ->(q) { q["criteria"] = [ "a" ] }, "question_structure" ],
    "select : une seule proposition" => [ "select", ->(q) { q["answers"].pop }, "question_structure" ],
    "select : onze propositions" => [ "select", ->(q) { q["answers"] = Array.new(11) { { "content" => "o#{it}", "correct" => it.zero? } } }, "schema" ],
    "select : deux bonnes" => [ "select", ->(q) { q["answers"].each { it["correct"] = true } }, "question_structure" ],
    "select : aucune bonne" => [ "select", ->(q) { q["answers"].each { it["correct"] = false } }, "question_structure" ],
    "select : deux trous" => [ "select", ->(q) { q["content"] = "___ et ___" }, "question_structure" ],
    "select : proposition vide" => [ "select", ->(q) { q["answers"][1]["content"] = " " }, "blank" ],
    "select : propositions identiques" => [ "select", ->(q) { q["answers"][1]["content"] = "Maison" }, "question_structure" ],
    "image en texte" => [ "written", ->(q) { q["image"] = "schema.png" }, "schema" ],
    "image sans description" => [ "written", ->(q) { q["image"] = {} }, "schema" ],
    "image : description de 151 caractères" => [ "written", ->(q) { q["image"] = { "description" => "a" * 151 } }, "schema" ],
    "image : description vide" => [ "written", ->(q) { q["image"] = { "description" => "" } }, "schema" ],
    "image : description qui n'est pas un texte" => [ "written", ->(q) { q["image"] = { "description" => 3 } }, "schema" ],
    "image : clé en trop" => [ "written", ->(q) { q["image"] = { "description" => "Un schéma", "url" => "x" } }, "schema" ],
    "image : description d'espaces" => [ "written", ->(q) { q["image"] = { "description" => "   " } }, "blank" ],
    "énoncé vide" => [ "written", ->(q) { q["content"] = " " }, "blank" ]
  }.freeze

  QUESTION_CASES.each do |label, (type, mutation, code)|
    test "parité question : #{label}" do
      assert_parity(label, with_question(type, &mutation), code)
    end
  end
end
