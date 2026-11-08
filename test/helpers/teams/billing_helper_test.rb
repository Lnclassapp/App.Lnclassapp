require "test_helper"

# Lot F : le premier du mois s'écrit « 1er » en français (« du 1er au 7 octobre »), jamais « 1 octobre ».
class Teams::BillingHelperTest < ActionView::TestCase
  Week = Struct.new(:starts_on, :ends_on)

  test "le premier jour du mois s'écrit 1er" do
    assert_equal "du 1er au 7 octobre", billing_week_range(Week.new(Date.new(2026, 10, 1), Date.new(2026, 10, 7)))
    assert_equal "du 6 au 12 novembre", billing_week_range(Week.new(Date.new(2026, 11, 6), Date.new(2026, 11, 12)))
  end

  test "une semaine à cheval sur deux mois nomme les deux" do
    assert_equal "du 30 octobre au 1er novembre", billing_week_range(Week.new(Date.new(2026, 10, 30), Date.new(2026, 11, 1)))
  end
end
