require "test_helper"
require Rails.root.join("script/contenus/valider")

# CA-19 : les 10 leçons de mathématiques de 3e de la progression 2026-2027 passent le script de contrôle sans erreur ni
# avertissement, et chacune s'importe en brouillon sur une base vide, par la vraie chaîne d'import (schéma puis adaptateur).
class Catalog::PilotLessonsTest < ActiveSupport::TestCase
  DIRECTORY = Rails.root.join("docs/contenus/lecons-traitees/3eme/mathematiques")
  LESSONS = %w[calcul-litteral proprietes-de-thales-dans-un-triangle racines-carrees triangle-rectangle calcul-numerique
               angles-inscrits vecteurs equations-et-inequations-dans-r pyramides-et-cones statistique].freeze

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

  test "les 10 leçons de 3e sont là, au format 3, dans l'ordre de la progression" do
    LESSONS.each_with_index do |slug, index|
      lesson = document(slug)
      assert_equal 3, lesson["version"], slug
      assert_equal "Leçon #{index + 1} — progression DPFC 2026-2027", lesson["courses"].first["subtitle"], slug
    end
  end

  LESSONS.each do |slug|
    test "#{slug} passe le script de contrôle sans erreur ni avertissement" do
      result = Contenus::Valider.new(document(slug)).call

      assert_empty result.errors, slug
      assert_empty result.warnings, slug
    end

    test "#{slug} s'importe en brouillon, avec ses notions, leurs fiches, ses figures et ses exercices" do
      lesson = document(slug)
      course = lesson["courses"].first

      report = import(lesson)

      assert_empty report.import_errors, slug
      assert_equal "completed", report.status
      imported = Orm::Course.find_by!(name: course["name"])
      assert_equal "draft", imported.status
      assert_equal course["figures"].to_a.size, imported.figures.size
      notions = imported.essentials.order(:position)
      assert_equal course["notions"].map { it["name"] }, notions.map(&:name)
      notions.each { |notion| assert_equal 4, notion.sheet.slice("remember", "method", "example", "pitfall").size, notion.name }
      exercises = Orm::Exercise.where(essential: notions).or(Orm::Exercise.where(course: imported))
      assert_equal course["notions"].size + 4, exercises.count
      assert exercises.all? { it.questions.count >= 5 }
    end
  end
end
