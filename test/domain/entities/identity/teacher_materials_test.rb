require "test_helper"

module Entities
  module Identity
    # ADR-0103 §4.2 (EPM-04, EPM-05): 1 to 3 subjects, without duplicate, in the given order.
    class TeacherMaterialsTest < ActiveSupport::TestCase
      test "one to three subjects are kept in their order, duplicates and blanks forgotten" do
        assert_equal [ 7 ], TeacherMaterials.build([ 7 ]).value
        assert_equal [ 9, 7, 8 ], TeacherMaterials.build([ 9, nil, 7, 9, 8 ]).value
      end

      test "none is refused as blank" do
        result = TeacherMaterials.build([ nil ])

        assert_equal [ :invalid, { material_slugs: [ :blank ] } ], [ result.code, result.errors ]
      end

      test "four are refused as too many" do
        result = TeacherMaterials.build([ 1, 2, 3, 4 ])

        assert_equal [ :invalid, { material_slugs: [ :too_many ] } ], [ result.code, result.errors ]
        assert_equal [ 1, 3 ], [ TeacherMaterials::MIN, TeacherMaterials::MAX ]
      end
    end
  end
end
