require "test_helper"
require Rails.root.join("script/contenus/valider")

# Les 10 premières leçons de SVT de 3e de la progression 2026-2027 : chacune a un fichier au format 3 sous l'intitulé exact de la
# progression (aucun format 1), passe le script de contrôle sans erreur ni avertissement et s'importe en brouillon sur une base vide,
# par la vraie chaîne d'import (schéma puis adaptateur).
class Catalog::SvtLessonsTest < ActiveSupport::TestCase
  DIRECTORY = Rails.root.join("docs/contenus/lecons-traitees/3eme/svt")
  PROGRESSION = Rails.root.join("docs/contenus/progressions-2026-2027/progressions-2026-2027-svt.json")
  # Dans l'ordre de la progression : [fichier, nombre de figures].
  FILES = {
    "Les aliments et l'Homme" => [ "les-aliments-et-l-homme", 3 ],
    "La digestion des aliments" => [ "la-digestion-des-aliments", 3 ],
    "Le sang" => [ "le-sang", 7 ],
    "La transfusion sanguine" => [ "la-transfusion-sanguine", 3 ],
    "La circulation sanguine" => [ "la-circulation-sanguine", 6 ],
    "Les grossesses précoces et les moyens de prévention" => [ "les-grossesses-precoces-et-les-moyens-de-prevention", 5 ],
    "L'infection au VIH" => [ "l-infection-au-vih", 5 ],
    "Les caractéristiques d'un sol" => [ "les-caracteristiques-d-un-sol", 5 ],
    "Les relations sols-plantes" => [ "les-relations-sols-plantes", 9 ],
    "La dégradation des sols" => [ "la-degradation-des-sols", 5 ]
  }.freeze

  def progression = JSON.parse(PROGRESSION.read)["courses"].select { it["level_name"] == "3ème" }.first(10)

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

  test "les 10 premières leçons de 3e de la progression ont chacune un fichier au format 3 sous leur intitulé exact" do
    lessons = progression

    assert_equal FILES.keys, lessons.map { it["name"] }
    assert_equal FILES.size, Dir[DIRECTORY.join("*.json")].size
    lessons.each_with_index do |lesson, index|
      slug, = FILES.fetch(lesson["name"])
      file = document(slug)
      course = file["courses"].first

      assert_equal 3, file["version"], slug
      assert_equal lesson["name"], course["name"], slug
      assert_equal "Leçon #{index + 1} — progression DPFC 2026-2027", course["subtitle"], slug
      assert_equal lesson["subtitle"], course["subtitle"], slug
    end
  end

  FILES.each do |name, (slug, figures)|
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
