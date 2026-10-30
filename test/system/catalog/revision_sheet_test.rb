require "application_system_test_case"

# CA-12 dans un navigateur — ce que seul un navigateur juge. Page de la leçon : la fiche n'est pas ouverte d'emblée, le bouton
# « Fiche de révision » l'ouvre entière en plein écran, la croix la ferme et rend le focus au bouton, une ancre l'ouvre à l'arrivée.
# Vue depuis une classe (UDR-0139 §3.3) : la suite masquée au chargement, « Voir plus » qui la déplie sans requête, « Voir moins »
# qui la replie et rend le focus au bouton. Le rendu serveur est jugé par test/integration/catalog/revision_sheet_test.rb.
class Catalog::RevisionSheetSystemTest < ApplicationSystemTestCase
  BUTTON = "[data-catalog--revision-more-target='button']".freeze
  REST = "[data-catalog--revision-more-target='rest']".freeze
  OPEN = "#fiche-de-revision button[aria-controls='revision-sheet']".freeze
  DIALOG = "dialog#revision-sheet".freeze

  setup do
    @course = create_course(name: "Racines carrées", content: "", sheet_theme: "teal")
    @student = create_student_for(@course)
    long = revision_notion("Notion longue").merge("remember" => Array.new(160) { "mot" }.join(" "))
    @essentials = [ long, revision_notion("Seconde notion") ].map do |notion|
      sheet = { "remember" => notion["remember"], "method" => notion["method"], "example" => notion["example"], "pitfall" => notion["pitfall"] }
      create_essential(course: @course, name: notion["name"], sheet:)
    end
  end

  def more = I18n.t("catalog.courses.show.revision_more")
  def less = I18n.t("catalog.courses.show.revision_less")
  def shown = I18n.t("catalog.courses.show.revision_shown")
  def requests = page.evaluate_script("performance.getEntriesByType('resource').filter((e) => ['fetch', 'xmlhttprequest'].includes(e.initiatorType)).length")
  def focused_in_rest? = page.evaluate_script("document.activeElement.matches(\"#{REST}\")")
  def focused?(selector) = page.evaluate_script("document.activeElement === document.querySelector(\"#{selector}\")")
  def no_sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
  # La boîte couvre la fenêtre, barre de défilement exceptée, une fois sa montée (animate-slide-up) finie.
  def dialog_fills_window?
    page.document.synchronize do
      covers = page.evaluate_script(<<~JS)
        (() => { const box = document.querySelector("#{DIALOG}").getBoundingClientRect(), root = document.documentElement
                 return box.left <= 0 && box.top <= 0 && box.right >= root.clientWidth - 1 && box.bottom >= window.innerHeight - 1 })()
      JS
      raise Capybara::ExpectationNotMet, "la boîte ne couvre pas la fenêtre" unless covers
    end
    true
  rescue Capybara::ExpectationNotMet
    false
  end

  test "the student sees only the « Fiche de révision » button, opens the whole sheet full screen and closes it" do
    sign_in_as @student
    visit course_path(@course.slug)

    assert_selector OPEN, text: "Fiche de révision"
    assert_no_selector ".sheet-box"
    assert_no_selector DIALOG

    assert_no_page_reload do
      find(OPEN).click

      within "#{DIALOG}[open]" do
        assert_selector "h2", text: "Fiche de révision"
        assert_selector "h4", text: "Seconde notion"
        assert_selector ".sheet-box[data-tone='pitfall']", count: 2
        assert_no_selector BUTTON
      end
      assert dialog_fills_window?, "la fiche ne prend pas toute la fenêtre"

      find("#{DIALOG} button[data-action='modal#close']").click
      assert_no_selector DIALOG
      assert focused?(OPEN), "le focus revient au bouton"
    end
  end

  test "an address to the sheet or to one of its notions opens it full screen, on arrival or when the address changes" do
    sign_in_as @student

    visit course_path(@course.slug, anchor: "fiche-de-revision")
    assert_selector "#{DIALOG}[open] h4", text: "Notion longue"
    find("#{DIALOG} button[data-action='modal#close']").click
    assert_no_selector DIALOG

    # Même page, autre ancre : seul `hashchange` le dit.
    visit course_path(@course.slug, anchor: "notion-#{@essentials.second.slug}")
    assert_selector "#{DIALOG}[open] h4", text: "Seconde notion"
  end

  test "on a phone, the button is a 48 px target and the sheet fills the screen without sideways scroll" do
    sign_in_as @student

    with_mobile_viewport do
      visit course_path(@course.slug)

      assert_operator find(OPEN).native.size.height, :>=, 48
      assert no_sideways_scroll?, "la page défile sur le côté"
      find(OPEN).click
      assert_selector "#{DIALOG}[open] h4", text: "Seconde notion"
      assert dialog_fills_window?, "la fiche ne prend pas tout l'écran"
      assert no_sideways_scroll?, "la page défile sur le côté, fiche ouverte"
    end
  end

  test "seen from a classroom, the teacher unfolds the sheet in place, folds it back and gets the focus on the button" do
    classroom = create_classroom(level: @course.level, series: @course.series)
    sign_in_as create_teacher(classrooms: [ classroom ])
    visit classroom_course_path(classroom.public_id, @course.slug)

    assert_selector ".sheet-box[data-tone='remember']", count: 1
    assert_no_selector "h4", text: "Seconde notion"
    assert_selector BUTTON, text: more
    assert_equal "false", find(BUTTON)["aria-expanded"]

    assert_no_page_reload do
      before = requests
      find(BUTTON).click

      assert_selector "h4", text: "Seconde notion"
      assert_selector BUTTON, text: less
      assert_equal "true", find(BUTTON)["aria-expanded"]
      assert focused_in_rest?, "le focus va au premier élément déplié"
      assert_equal shown, find("[data-catalog--revision-more-target='status']", visible: :all)[:textContent]
      assert_equal before, requests, "« Voir plus » n'envoie aucune requête"
    end

    find(BUTTON).click

    assert_no_selector "h4", text: "Seconde notion"
    assert_selector BUTTON, text: more
    assert focused?(BUTTON), "le focus revient au bouton"
  end
end
