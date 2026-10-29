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

  def explanation(document_course, value) = (document_course["exercises"][0]["questions"][0]["explanation"] = value)

  test "la leçon de la fabrique : ni l'import ni le script ne refusent" do
    assert_empty import_pairs(revision_sheet_document)
    assert_empty script_pairs(revision_sheet_document)
  end

  test "parité : version retirée, version inconnue, autre format" do
    [ [ 2, "format_retired" ], [ 4, "version_unsupported" ] ].each do |version, code|
      assert_parity("version #{version}", revision_sheet_document.merge("version" => version), code)
    end
    assert_parity("autre format", revision_sheet_document.merge("format" => "lnclass.autre"), "format_mismatch")
  end

  CASES = {
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
end
