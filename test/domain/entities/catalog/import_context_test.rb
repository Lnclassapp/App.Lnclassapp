require "test_helper"

module Entities
  module Catalog
    class ImportContextTest < ActiveSupport::TestCase
      test "cible, clés existantes et référentiels de l'adaptateur" do
        context = ImportContext.new(target: nil, existing_keys: Set[[ 1, "svt" ]])

        assert_equal({}, context.data)
        assert_includes context.existing_keys, [ 1, "svt" ]
        assert_equal :lookup, ImportContext.new(target: 3, existing_keys: Set.new, data: { lookup: :lookup }).data[:lookup]
      end
    end
  end
end
