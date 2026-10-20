require "test_helper"

module Queries
  module Catalog
    # CC-22 (UDR-0113 §3.9) : la bande « Matières » de la homepage lit les matières qui ont un cours publié, dans l'ordre du
    # programme, en une requête.
    class HomepageMaterialsQueryTest < ActiveSupport::TestCase
      test "the materials with a published course, in the program order, in one query" do
        level = create_level
        create_course(level:, material: create_material(name: "SVT"))
        create_course(level:, material: create_material(name: "Mathématiques"))
        create_course(level:, material: create_material(name: "Allemand", position: nil))
        create_course(level:, material: create_material(name: "Philosophie", category: "literature"), status: "draft")

        materials = assert_queries_count(1) { HomepageMaterialsQuery.new.call }

        assert_equal [ [ "mathematiques", "Mathématiques", "science" ], [ "svt", "SVT", "science" ], [ "allemand", "Allemand", "science" ] ],
                     materials
      end
    end
  end
end
