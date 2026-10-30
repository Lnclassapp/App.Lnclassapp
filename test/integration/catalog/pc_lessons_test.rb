require "test_helper"
require Rails.root.join("script/contenus/valider")

# CA-9, CA-10, CA-11 : les 10 leçons de Physique-Chimie de 3e de la progression 2026-2027 sont là, aux intitulés exacts, au format 3 ; celles dont
# les figures sont connues passent le script de contrôle sans erreur ni avertissement, et chacune s'importe en brouillon sur une base vide, par la vraie chaîne d'import.
class Catalog::PcLessonsTest < ActiveSupport::TestCase
  DIRECTORY = Rails.root.join("docs/contenus/lecons-traitees/3eme/physique-chimie")
  PROGRESSION = Rails.root.join("docs/contenus/progressions-2026-2027/progressions-2026-2027-physique-chimie.json")
  # Dans l'ordre de la progression : [fichier, nombre de figures]. L'intitulé vient du JSON de progression (3ème, Physique-Chimie).
  LESSONS = [
    [ "masse-et-poids-d-un-corps", 2 ],
    [ "les-forces", 5 ],
    [ "equilibre-d-un-solide-soumis-a-deux-forces", 5 ],
    [ "travail-et-puissance-mecaniques", 4 ],
    [ "energie-mecanique", 3 ],
    [ "electrolyse-et-synthese-de-l-eau", 6 ],
    [ "les-alcanes", 5 ],
    [ "les-lentilles", 3 ],
    [ "les-defauts-de-l-oeil-et-leurs-corrections", 5 ],
    [ "oxydation-des-corps-purs-simples", 4 ]
  ].freeze
  TITLES = JSON.parse(PROGRESSION.read)["courses"].select { it["level_name"] == "3ème" }.map { it["name"] }.freeze

  setup do
    seed_referential
    @author = create_team_member(team_role: "content", second_factor: false)
  end

  def document(slug) = JSON.parse(DIRECTORY.join("#{slug}.json").read)

  def import(document)
    report = create_import_report(kind: "course_tree", imported_by: @author)
    Repositories::Catalog::ImportFileStore.new.attach(report_id: report.id,
                                                      files: [ import_upload(io: StringIO.new(document.to_json), filename: "lecon.json") ])
    UseCases::Catalog::RunImport.new(
      adapter: Catalog::ImportCourseTreeJob.new.send(:adapter), reports: Repositories::Catalog::ImportReportRepository.new,
      files: Repositories::Catalog::ImportFileStore.new, schema: Repositories::Catalog::ImportSchemaValidator.new,
      users: Repositories::Identity::UserRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(report_id: report.id)
    report.reload
  end

  test "les 10 leçons sont là, au format 3, dans l'ordre de la progression, sous leur intitulé" do
    assert_equal LESSONS.size, Dir[DIRECTORY.join("*.json")].size
    assert_operator TITLES.size, :>=, LESSONS.size
    LESSONS.each_with_index do |(slug, _), index|
      course = document(slug)["courses"].first
      name = TITLES.fetch(index)
      assert_equal "3ème", course["level_name"], slug
      assert_equal "Physique-Chimie", course["material_name"], slug
      assert_equal 3, document(slug)["version"], slug
      assert_equal "Leçon #{index + 1} — progression DPFC 2026-2027", course["subtitle"], slug
      assert_equal name, course["name"], slug
    end
  end

  LESSONS.each_with_index do |(slug, figures), index|
    name = TITLES.fetch(index)

    test "#{slug} passe le script de contrôle sans erreur ni avertissement" do
      result = Contenus::Valider.new(document(slug)).call

      assert_empty result.errors, slug
      assert_empty result.warnings, slug
    end

    test "#{slug} s'importe en brouillon, avec ses #{figures} figures" do
      report = import(document(slug))

      assert_empty report.import_errors, slug
      assert_equal "completed", report.status
      imported = Orm::Course.find_by!(name: name)
      assert_equal "draft", imported.status
      assert_equal figures, imported.figures.size
    end
  end
end
