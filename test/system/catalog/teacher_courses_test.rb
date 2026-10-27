require "application_system_test_case"

# CA-G5, CA-N1 (UDR enseignant §3.7) : le Cours de l'enseignant sur téléphone. Un rond de niveau l'ouvre, titré « Cours de
# Tle D » ; un bivalent change de matière par les puces ; une carte porte ses fiches de révision. Le reste (menus, puces
# de l'établissement courant, carte sans fiche) est lu dans test/controllers/catalog/courses_controller_test.rb.
class Catalog::TeacherCoursesTest < ApplicationSystemTestCase
  setup do
    @level = create_level(name: "Tle")
    @series = create_series(name: "D")
    link_level_series(level: @level, series: @series)
    @maths = create_material(name: "Mathématiques", shortname: "Maths")
    @pc = create_material(name: "Physique-Chimie", shortname: "PC")
    @limits = create_course(name: "Limites et continuité", level: @level, series: @series, material: @maths,
                            subtitle: "Leçon 1 · Progression DPFC 2026-2027")
    @derivatives = create_course(name: "Fonctions dérivées", level: @level, series: @series, material: @maths,
                                 subtitle: "Leçon 2 · Progression DPFC 2026-2027")
    @mechanics = create_course(name: "Mécanique", level: @level, series: @series, material: @pc)
    @infinity = create_essential(course: @limits, name: "Limites en l'infini")
    @teacher = create_teacher(materials: [ @maths, @pc ], classrooms: [ create_classroom(level: @level, series: @series) ])
  end

  test "on a phone, the teacher opens « Cours de Tle D », switches subject by chip, searches and opens a review sheet" do
    sign_in_as @teacher

    with_mobile_viewport do
      visit courses_path(level: "tle", series: "d")
      assert_selector "h1", text: "Cours de Tle D"
      assert_no_selector "form#courses-filters select"
      assert_selector "#courses_material_chips a[aria-current=true]", text: "Maths"
      assert_selector "#courses_list > li", count: 2
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"

      assert_no_page_reload do
        fill_in I18n.t("catalog.courses.index.filters.search"), with: "derivees"
        assert_selector "#courses_list > li", count: 1
        assert_selector "#course_#{@derivatives.slug}"
      end

      find("#courses_material_chips a", text: "PC").click
      assert_selector "#course_#{@mechanics.slug}"
      assert_no_selector "#course_#{@limits.slug}"

      find("#courses_material_chips a", text: "Maths").click
      click_on "Limites en l'infini"
      assert_current_path course_essential_path(@limits.slug, @infinity.slug)
    end
  end

  test "at 1280 px, the teacher reads one column of 40 rem, lessons in the order of the progression, « Cours » active in the sidebar" do
    # Lesson 10 is the oldest and first in the alphabet: an order by creation date or by name would put it first, not last.
    algebra = create_course(name: "Algèbre", level: @level, series: @series, material: @maths, subtitle: "Leçon 10 · Progression DPFC 2026-2027",
                            created_at: 1.year.ago)
    sign_in_as @teacher

    with_window([ 1280, 900 ]) do
      visit courses_path(level: "tle", series: "d")
      assert_selector "h1", text: "Cours de Tle D"

      assert_selector "aside a[aria-current=page]", text: I18n.t("shared.navigation.courses")
      assert_selector "aside a[aria-current=page]", count: 1
      assert_equal %W[course_#{@limits.slug} course_#{@derivatives.slug} course_#{algebra.slug}],
                   all("#courses_list > li").map { it[:id] }

      boxes = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("#courses_list > li")).map((li) => {
          const box = li.getBoundingClientRect()
          return { left: box.left, width: box.width, top: box.top }
        })
      JS
      assert_equal 1, boxes.map { it["left"].round }.uniq.size, "les cartes ne sont pas sur une seule colonne"
      assert_operator boxes.first["width"], :<=, 640.5
      assert_operator boxes.first["width"], :>, 560
      assert_equal boxes.map { it["top"] }, boxes.map { it["top"] }.sort
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
    end
  end

  private

  def with_window(size)
    window = page.current_window
    original = window.size
    window.resize_to(*size)
    yield
  ensure
    window.resize_to(*original)
  end
end
