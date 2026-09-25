require "test_helper"

module Entities
  module Catalog
    class SlugTest < ActiveSupport::TestCase
      test "dérive le slug du nom et le réserve" do
        taken = Set.new

        assert_equal "genetique-humaine", Slug.unique("Génétique humaine", taken:)
        assert_includes taken, "genetique-humaine"
      end

      test "suffixe -2, -3… en cas de collision" do
        taken = Set["svt", "svt-2"]

        assert_equal "svt-3", Slug.unique("SVT", taken:)
        assert_equal "svt-4", Slug.unique("SVT", taken:)
      end
    end
  end
end
