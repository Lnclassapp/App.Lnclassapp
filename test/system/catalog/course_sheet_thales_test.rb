require "application_system_test_case"

# contenu-en-blocs (chantier 318), Lot D, CA-9: the Thalès sheet of the seeds, read in a real browser. The figure follows
# the pointer (mouse and finger alike, pointer events), M drags N along while the lock holds, « Libérer N » tests the
# converse, « Réinitialiser » restores A(70,165), B(360,55), C(345,285), kM = kN = 0,45; exercises and the generator work.
class Catalog::CourseSheetThalesTest < ApplicationSystemTestCase
  FIGURE = "[data-controller~='course-sheet--thales-figure']".freeze

  setup do
    @course = create_course(name: "Propriétés de Thalès dans un triangle", level: create_level(name: "3ème"))
    create_course_sheet(course: @course, document: JSON.parse(Rails.root.join("db/seeds/data/course_sheets/thales.json").read))
    sign_in_as create_student_for(@course)
    visit course_sheet_path(@course.slug)
    assert_selector FIGURE
  end

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)
  def figure(key, **) = t("kinds.thales_figure.#{key}", **)
  def role(name) = find("#{FIGURE} [data-role='#{name}']")
  def cell(name) = find("#{FIGURE} [data-cell='#{name}']").text
  def ratios = %w[1 2 3].map { find("#{FIGURE} [data-ratio='#{it}']").text }

  # Drags a point of the figure to a place of the 440 × 320 drawing, with real pointer events (Selenium actions).
  def drag(point, x:, y:)
    page.execute_script("document.querySelector(\"#{FIGURE} svg\").scrollIntoView({ block: 'center' })")
    handle = find("#{FIGURE} circle[data-hit='#{point}']")
    scale = page.evaluate_script("document.querySelector(\"#{FIGURE} svg\").getBoundingClientRect().width / 440")
    from = [ handle[:cx].to_f, handle[:cy].to_f ]
    page.driver.browser.action.move_to(handle.native).click_and_hold
        .move_by(((x - from[0]) * scale).round, ((y - from[1]) * scale).round).release.perform
  end

  test "the figure starts in its initial position, without any mark of the maquette missing" do
    assert_equal figure("config_triangle"), role("config").text
    assert_equal %w[0,45 0,45 0,45], ratios
    assert_equal [ "7,8", "7,5", "5,8" ], %w[AB AC BC].map { cell(it) }
    assert_equal %w[A B C M N], all("#{FIGURE} svg text").map(&:text)
    assert_equal figure("status_locked"), role("status").text
  end

  test "moving M, locked, moves N along: the three ratios stay equal and the configuration is the butterfly" do
    drag("M", x: 30, y: 180)

    assert_equal figure("config_butterfly"), role("config").text
    assert_equal 1, ratios.uniq.size, ratios.inspect
    assert_not_equal "0,45", ratios.first
    assert_equal figure("status_locked"), role("status").text
  end

  test "« Libérer N » tests the converse, « Imposer » restores the parallel, « Réinitialiser » restores the figure" do
    click_on figure("lock_free")
    drag("N", x: 250, y: 200)

    assert_equal figure("status_contraposed"), role("status").text
    assert_not_equal ratios[0], ratios[1], ratios.inspect
    assert_button figure("lock_impose")

    click_on figure("lock_impose")
    assert_equal figure("status_locked"), role("status").text
    assert_equal 1, ratios.uniq.size

    drag("M", x: 150, y: 120)
    click_on t("figure.reset")

    assert_equal figure("config_triangle"), role("config").text
    assert_equal %w[0,45 0,45 0,45], ratios
    assert_button figure("lock_free")
  end

  test "a student solves an exercise and the generator counts the first answer once" do
    card = find(".sheet-card", text: "Exercice 4")
    within(card) do
      find("input[data-field-id='e4an']").set("3,6")
      find("input[data-field-id='e4mn']").set("4.2")
      click_on t("exercise.check")
      assert_text t("exercise.all_correct")
    end

    practice = find("section[data-controller~='course-sheet--practice']")
    within(practice) do
      assert_text t("practice.score", ok: 0, total: 0)
      click_on t("practice.solution")
      answer = find("[data-course-sheet--practice-target='solution']").text[/=\s*([\d,]+) cm\.\z/, 1]
      assert answer, "la solution ne se termine pas par « = … cm. »"
      find("input[data-course-sheet--practice-target='input']").set(answer)
      click_on t("practice.check")
      click_on t("practice.check")

      assert_text t("practice.score", ok: 1, total: 1)
    end
  end

  test "on a phone the sheet does not scroll sideways and the figure fits its page" do
    with_mobile_viewport do
      visit course_sheet_path(@course.slug)

      assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      handle = find("#{FIGURE} circle[data-hit='M']")
      assert_operator page.evaluate_script("arguments[0].getBoundingClientRect().width", handle), :>=, 44
    end
  end
end
