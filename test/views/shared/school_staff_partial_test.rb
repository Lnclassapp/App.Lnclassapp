require "test_helper"

# UDR-0070 §3.4 : le bloc « Direction » liste les comptes, leur arrivée et les places ; ⋮ « Retirer » seulement où permis.
class SchoolStaffPartialTest < ActionView::TestCase
  Row = Queries::School::SchoolStaffQuery::Row

  setup do
    @kofi = Row.new(user_id: 1, public_id: "kofi", name: "Kofi Yao", joined_via: "invitation", joined_at: Time.zone.parse("2026-10-01 09:00"))
    @aya = Row.new(user_id: 2, public_id: "aya", name: "Aya Kouassi", joined_via: "code", joined_at: Time.zone.parse("2026-09-04 09:00"))
  end

  def block(staff: [ @kofi, @aya ], removable: ->(row) { row.user_id != 1 }, remove_url: ->(id) { "/staff/#{id}" }, newcomer: false)
    render partial: "shared/school_staff", locals: { staff:, by_code_count: 1, viewer_id: 1, remove_url:, removable:, newcomer: }
    Nokogiri::HTML.fragment(rendered)
  end

  test "lists each account with its arrival, the reader marked, and the places by code" do
    html = block

    assert_includes html.at_css("#school_staff_places").text, "1 / 3 comptes créés avec le code"
    assert_includes html.at_css("#school_staff_kofi").text, "(vous)"
    assert_includes html.at_css("#school_staff_kofi").text, "Depuis le 1er octobre 2026 · sur invitation"
    assert_includes html.at_css("#school_staff_aya").text, "Depuis le 4 septembre 2026 · avec le code"
  end

  test "the menu and its confirmation appear only on removable rows" do
    html = block

    assert_nil html.at_css("#staff-actions-kofi")
    assert html.at_css("#staff-actions-aya")
    assert_equal "/staff/aya", html.at_css("form#remove-staff-aya-form")["action"]
    assert_includes html.at_css("#remove-staff-aya").text, "Retirer Aya Kouassi de la direction ?"
  end

  test "without a remove url, no row has a menu; the newcomer note shows when asked" do
    html = block(remove_url: nil, newcomer: true)

    assert_empty html.css("[id^='staff-actions-']")
    assert_includes html.at_css("#school_staff_newcomer").text, "7 jours après votre arrivée"
  end

  test "without the newcomer flag, no note" do
    assert_nil block.at_css("#school_staff_newcomer")
  end

  test "an empty block says so" do
    assert_includes block(staff: []).text, "Aucun compte direction"
  end
end
