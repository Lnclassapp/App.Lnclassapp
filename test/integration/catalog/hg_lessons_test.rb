require "test_helper"
require Rails.root.join("script/contenus/valider")

# CA-9, CA-10, CA-11 : les 10 leçons d'Histoire-Géographie de 3e de la progression 2026-2027 passent le script de contrôle sans
# erreur ni avertissement, et chacune s'importe en brouillon sur une base vide, par la vraie chaîne d'import (schéma puis adaptateur).
class Catalog::HgLessonsTest < ActiveSupport::TestCase
  DIRECTORY = Rails.root.join("docs/contenus/lecons-traitees/3eme/histoire-geographie")
  # Dans l'ordre de la progression : [fichier, intitulé de la leçon, nombre de figures].
  LESSONS = [
    [ "histoire-le-mouvement-imperialiste-et-la-colonisation-en-cote-d-ivoire", "Histoire — Le mouvement impérialiste et la colonisation en Côte d'Ivoire", 3 ],
    [ "geographie-les-atouts-du-developpement-economique-de-la-cote-d-ivoire", "Géographie — Les atouts du développement économique de la Côte d'Ivoire", 2 ],
    [ "histoire-l-accession-de-la-cote-d-ivoire-a-l-independance", "Histoire — L'accession de la Côte d'Ivoire à l'indépendance", 2 ],
    [ "geographie-les-secteurs-d-activites-economiques-de-la-cote-d-ivoire", "Géographie — Les secteurs d'activités économiques de la Côte d'Ivoire", 3 ],
    [ "histoire-causes-et-caracteres-des-crises-sociopolitiques-de-l-afrique-independante", "Histoire — Causes et caractères des crises sociopolitiques de l'Afrique indépendante", 2 ],
    [ "histoire-la-crise-rwandaise-de-la-guerre-au-genocide-des-tutsi-1990-1994", "Histoire — La crise rwandaise : de la guerre au génocide des tutsi (1990-1994)", 2 ],
    [ "geographie-les-problemes-du-developpement-economique-de-la-cote-d-ivoire", "Géographie — Les problèmes du développement économique de la Côte d'Ivoire", 2 ],
    [ "histoire-les-causes-les-caracteres-et-les-consequences-de-la-deuxieme-guerre-mondiale", "Histoire — Les causes, les caractères et les conséquences de la deuxième guerre mondiale", 2 ],
    [ "geographie-etude-economique-de-l-afrique", "Géographie — Etude Economique de l'Afrique", 4 ],
    [ "histoire-l-organisation-des-nations-unies-onu", "Histoire — L'Organisation des Nations Unies (ONU)", 3 ]
  ].freeze

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
    LESSONS.each_with_index do |(slug, name, _), index|
      course = document(slug)["courses"].first
      assert_equal 3, document(slug)["version"], slug
      assert_equal "Leçon #{index + 1} — progression DPFC 2026-2027", course["subtitle"], slug
      assert_equal name, course["name"], slug
    end
  end

  LESSONS.each do |slug, name, figures|
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
