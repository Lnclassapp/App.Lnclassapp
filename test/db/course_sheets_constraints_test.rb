require "test_helper"

# ADR-0110 (contenu-en-blocs, #318) : ce que la table garantit seule, sans passer par l'entité.
class CourseSheetsConstraintsTest < ActiveSupport::TestCase
  test "la fiche de référence s'écrit et se relit, document compris" do
    sheet = create_course_sheet.reload

    assert_equal "blue", sheet.theme
    assert_equal 1, sheet.format_version
    assert_equal course_sheet_document, sheet.document
    assert_predicate Entities::Catalog::SheetDocument.new(sheet.document), :valid?
  end

  test "une seule fiche par leçon" do
    sheet = create_course_sheet

    assert_raises(ActiveRecord::RecordNotUnique) { create_course_sheet(course: sheet.course) }
  end

  test "un thème hors liste est refusé par la base" do
    assert_raises(ActiveRecord::StatementInvalid) { create_course_sheet(theme: "red") }
  end

  test "un document nul est refusé" do
    assert_raises(ActiveRecord::NotNullViolation) { create_course_sheet(document: nil) }
  end

  test "une leçon qui a sa fiche ne se supprime pas" do
    sheet = create_course_sheet

    assert_raises(ActiveRecord::InvalidForeignKey) { sheet.course.destroy! }
    assert Orm::CourseSheet.exists?(sheet.id)
  end
end
