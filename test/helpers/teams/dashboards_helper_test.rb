require "test_helper"

# UDR-0049: the bars of the level distribution are pure CSS. UDR-0005 forbids the style attribute and arbitrary values:
# the width is one of 21 literal Tailwind fractions, in steps of 5 %.
module Teams
  class DashboardsHelperTest < ActionView::TestCase
    test "zero gives an empty bar, a hundred a full one" do
      assert_equal "w-0", dashboard_bar_width(0)
      assert_equal "w-full", dashboard_bar_width(100)
    end

    test "a share rounds to the nearest step of 5 %" do
      assert_equal "w-5/20", dashboard_bar_width(25)
      assert_equal "w-5/20", dashboard_bar_width(27)
      assert_equal "w-6/20", dashboard_bar_width(28)
      assert_equal "w-19/20", dashboard_bar_width(96)
    end

    test "a level that has students always shows a visible bar" do
      assert_equal "w-1/20", dashboard_bar_width(1)
    end

    test "out of range values are clamped" do
      assert_equal "w-0", dashboard_bar_width(-3)
      assert_equal "w-full", dashboard_bar_width(140)
    end

    test "the 21 widths are literal classes, compiled by Tailwind" do
      assert_equal 21, DashboardsHelper::BAR_WIDTHS.size
      assert_equal %w[w-0 w-1/20 w-2/20], DashboardsHelper::BAR_WIDTHS.first(3)
      assert_equal "w-full", DashboardsHelper::BAR_WIDTHS.last
    end
  end
end
