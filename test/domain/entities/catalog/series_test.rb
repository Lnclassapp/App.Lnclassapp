require "test_helper"

module Entities
  module Catalog
    class SeriesTest < ActiveSupport::TestCase
      test "nom obligatoire, 10 caractères au plus" do
        assert Series.new(slug: "a1", name: " A1 ").valid?
        assert_equal "A1", Series.new(name: " A1 ").name
        assert Series.new(name: nil).invalid?
        assert Series.new(name: "a" * 11).invalid?
      end
    end
  end
end
