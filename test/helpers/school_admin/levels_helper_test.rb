require "test_helper"

# UDR-0072 §3.6: each level has its own drawing, chosen by the frozen slug of the level, on its own tint; any other slug
# falls back to the generic drawing of UDR-0069. The files exist and follow the rules of the drawings (no style, no class).
module SchoolAdmin
  class LevelsHelperTest < ActionView::TestCase
    include ComponentsHelper

    EXPECTED = { "6eme" => %w[6eme bg-tint-yellow], "5eme" => %w[5eme bg-tint-green], "4eme" => %w[4eme bg-tint-lilac],
                 "3eme" => %w[3eme bg-tint-indigo], "2nde" => %w[2nde bg-tint-lavender], "1ere" => %w[1ere bg-tint-red],
                 "tle" => %w[tle bg-tint-pink] }.freeze

    test "the seven levels have their drawing and their tint" do
      EXPECTED.each do |slug, (file, tint)|
        assert_equal ComponentsHelper::Illustration.new(path: "levels/#{file}.svg", tint:), level_illustration(slug), slug
      end
    end

    test "an unknown or missing level falls back to the generic drawing" do
      fallback = ComponentsHelper::Illustration.new(path: "subjects/generique.svg", tint: "bg-mist")

      assert_equal fallback, level_illustration("7eme")
      assert_equal fallback, level_illustration(nil)
    end

    test "each drawing is a standalone 48 × 48 SVG, without style attribute nor class" do
      EXPECTED.each_value do |file, _|
        svg = Rails.root.join("app/assets/images/levels/#{file}.svg").read

        assert_match %r{\A<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">}, svg, file
        assert_no_match(/style=|class=/, svg, file)
      end
    end
  end
end
