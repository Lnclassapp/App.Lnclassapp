require "test_helper"

module Queries
  module Catalog
    # Squelette du Lot 0 : le contrat gelé, rendu vide. Le Lot A le complète.
    class RevisionSheetQueryTest < ActiveSupport::TestCase
      test "le contrat porte kind, sheet, texts et cut, et rend « vide » tant que le Lot A n'est pas là" do
        assert_equal %i[kind sheet texts cut], RevisionSheetQuery::Revision.members

        revision = RevisionSheetQuery.new.call(course_slug: create_course.slug, actor: nil)

        assert_equal [ :empty, nil, [], nil ], [ revision.kind, revision.sheet, revision.texts, revision.cut ]
      end
    end
  end
end
