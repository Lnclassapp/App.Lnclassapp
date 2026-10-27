require "test_helper"

module Entities
  module Catalog
    class CourseSheetTest < ActiveSupport::TestCase
      def document = JSON.parse(Rails.root.join("test/fixtures/files/course_sheets/reference.json").read)

      def build(**overrides)
        CourseSheet.new(course_id: 1, theme: "blue", document:, format_version: 1, **overrides)
      end

      test "une fiche complète est valide, ses thèmes sont fermés" do
        assert_predicate build, :valid?
        assert_equal %w[blue teal burgundy], CourseSheet::THEMES
        CourseSheet::THEMES.each { assert_predicate build(theme: it), :valid? }
      end

      test "exige une leçon, un thème connu et la version 1" do
        assert build(course_id: nil).invalid?
        assert build(theme: "red").invalid?
        assert build(theme: nil).invalid?
        assert build(format_version: 2).invalid?
      end

      test "refuse un document invalide et rend ses erreurs" do
        sheet = build(document: document.merge("extra" => 1))

        assert sheet.invalid?
        assert_equal [ :unknown_key ], sheet.document_errors.map(&:reason)
        assert_includes sheet.errors[:document], "document : unknown_key (extra)"
      end

      test "expose le document validé et ses pages" do
        sheet = build

        assert_instance_of SheetDocument, sheet.sheet_document
        assert_equal 3, sheet.pages.size
        assert_equal %w[hypothese paralleles secantes], sheet.glossary.keys.sort
      end
    end
  end
end
