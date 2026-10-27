# Fiche de cours (contenu-en-blocs, Lot B) : le document de référence réduit aux blocs que la lecture sait rendre.
# Les partials des exercices, des figures et des kinds sont ceux des lots C à F ; `_block` ne gère pas un partial absent.
module CourseSheetReading
  ActiveSupport::TestCase.include(self)

  READABLE_BLOCK_TYPES = %w[paragraph box simple steps table].freeze

  def reading_course_sheet_document
    document = course_sheet_document
    document["pages"].each do |page|
      page["sections"].each { |section| section["blocks"].select! { READABLE_BLOCK_TYPES.include?(it["type"]) } }
    end
    document
  end
end
