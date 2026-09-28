require "application_system_test_case"

# ED-04, UDR-0052 §3.1 and §3.7: the shell of the direction — five active destinations, the detail « <Fonction> ·
# <Établissement> » — and the « Établissement » page, on a desktop and on a 390 px phone without horizontal scroll.
# The frames of the code (Lot G) and of the staff (Lot B) are not read here: their controllers arrive with those lots.
class SchoolAdmin::ShellTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Moderne de Treichville", drena: create_drena(name: "Abidjan 2"), school_type: "public")
    @censor = create_school_admin(school: @school, position: "censor", first_name: "Awa")
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")

  def assert_no_horizontal_scroll(label)
    assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"), label
  end

  test "ED-04: on a desktop, the censor sees five active destinations and her position at her school" do
    sign_in_as @censor

    assert_current_path school_admin_home_path
    within("aside") do
      assert_text "Censeur · Lycée Moderne de Treichville"
      within("nav") { %i[home classrooms teachers students school].each { |key| assert_selector "a[href]", text: tn(key) } }
      click_link tn(:school)
    end

    assert_current_path school_admin_school_path
    assert_selector "h1", text: "Lycée Moderne de Treichville"
    assert_text "Abidjan 2 · Public"
    assert_selector "turbo-frame#school_code"
    assert_selector "turbo-frame#school_staff"
  end

  test "ED-04: at 390 px, the bottom bar holds the five destinations, and no page scrolls sideways" do
    sign_in_as @censor

    with_mobile_viewport do
      assert_no_horizontal_scroll "accueil"
      within("nav.bottom-0") do
        assert_selector "a[href]", count: 5
        assert_no_selector "a[aria-disabled]"
        click_link tn(:school)
      end

      assert_current_path school_admin_school_path
      assert_selector "h1", text: "Lycée Moderne de Treichville"
      within("nav.bottom-0") { assert_selector "a[aria-current='page'][href='#{school_admin_school_path}']", text: tn(:school) }
      assert_no_horizontal_scroll "établissement"
    end
  end
end
