# Fiche de cours d'une leçon (contenu-en-blocs, #318) : le document de référence, valide, sur une leçon créée à la demande.
module Factories
  module CourseSheet
    ActiveSupport::TestCase.include(self)

    REFERENCE_DOCUMENT = "test/fixtures/files/course_sheets/reference.json".freeze

    def course_sheet_document
      JSON.parse(Rails.root.join(REFERENCE_DOCUMENT).read)
    end

    def create_course_sheet(course: create_course, theme: "blue", document: course_sheet_document, **attributes)
      Orm::CourseSheet.create!(course:, theme:, document:, **attributes)
    end
  end
end
