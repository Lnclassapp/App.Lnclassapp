require "test_helper"

module Entities
  module Catalog
    class NameKeyTest < ActiveSupport::TestCase
      test "ignore espaces, casse et accents" do
        assert_equal "genetique et heredite", NameKey.call("  Génétique   et HÉRÉDITÉ ")
        assert_equal "", NameKey.call(nil)
      end
    end
  end
end
