require "application_system_test_case"

# rendu-lecons-v3-390 : à 390 px, une formule KaTeX trop large défile dans son propre cadre, jamais la page. Trois endroits qui
# débordaient : la fiche de révision, le « À retenir » d'une feuille « Prépare interros » et le libellé d'une question.
class Catalog::LongFormulasTest < ApplicationSystemTestCase
  # lecons-defauts-affichage : une équation de réaction en ligne, telle que dans les leçons de chimie de Tle.
  REACTION = "$\\mathrm{(R-CO)_{2}O + 2 NH_{3} \\to R-CO-NH_{2} + R-COO^- + NH_{4}^+}$".freeze
  LONG = "$$" + Array.new(14) { |i| "\\int_{#{i}}^{#{i + 1}} f(x)\\,dx" }.join(" + ") + " = \\sum_{k=0}^{13} W(\\vec{F}_{ext,k})$$".freeze

  setup do
    @course = create_course(name: "Calcul intégral", content: "")
    @notion = create_essential(course: @course, name: "Intégrale", position: 1,
                               sheet: { "remember" => "Retiens : #{LONG}", "method" => [ "a", "b", "c", "d" ], "example" => { "statement" => "x", "steps" => %w[a b c] },
                                        "pitfall" => "Piège" })
    exercise = create_exercise(essential: @notion, title: "Premier", questions: 0)
    exercise.questions.create!(position: 1, content: "Calcule #{LONG}", question_type: "single_choice").tap do |q|
      [ "1", "2" ].each_with_index { |c, i| q.answers.create!(position: i + 1, content: c, correct: i.zero?) }
    end
    sign_in_as create_student_for(@course)
  end

  def sheet_page = fill_course_sheet_path(@course.slug, "notion-#{@notion.slug}")

  def no_sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def displays_fit?
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".katex-display")].every((el) => el.getBoundingClientRect().right <= window.innerWidth + 1)
    JS
  end

  test "on a phone a long display formula scrolls in its own frame, never the page" do
    with_mobile_viewport do
      visit course_path(@course.slug)
      assert_selector ".sheet-text .katex-display", wait: 10
      assert no_sideways_scroll?, "la page défile sur le côté"
      assert displays_fit?, "une formule dépasse l'écran"

      # La feuille se remplit sur sa propre page (sujet-avant-de-commencer).
      visit sheet_page
      assert_selector ".ps-remember .katex-display", wait: 10
      assert_selector ".ps-question-label .katex-display"
      assert no_sideways_scroll?, "la feuille défile sur le côté"
      assert displays_fit?, "une formule de la feuille dépasse l'écran"
      assert no_sideways_scroll?, "la page défile sur le côté"
      assert displays_fit?, "une formule dépasse l'écran"
    end
  end

  # lecons-defauts-affichage : trois endroits du bloc exercice qui élargissaient encore la page à 390 px.
  test "on a phone a long inline formula in a multiple choice answer stays in its frame" do
    exercise = create_exercise(essential: @notion, title: "Second", questions: 0)
    create_kind_question(exercise:, question_type: "single_choice", answers: [ REACTION, "Rien" ], content: "Quelle équation ?")

    assert_phone_fits ".ps-choice-label .katex"
  end

  test "on a phone a long inline formula in a matching board stays in its frame" do
    exercise = create_exercise(essential: @notion, title: "Second", questions: 0)
    create_kind_question(exercise:, question_type: "matching", answers: [ [ "Anhydride", REACTION ], [ "Acide", "$\\mathrm{R-COOH}$" ] ],
                                    content: "Relie chaque réactif à son équation.")

    assert_phone_fits "[data-assessment--matching-target=board] .katex"
  end

  test "on a phone a long inline formula in an exercise statement stays in its frame" do
    create_exercise(essential: @notion, title: "Second", questions: 1, statement: "On considère la réaction #{REACTION} à chaud.")

    assert_phone_fits ".ps-statement .katex"
  end

  test "on a phone a wide data table in an exercise statement scrolls in its own frame" do
    headers = %w[Athlétisme Football Basketball Natation Handball Volleyball]
    create_exercise(essential: @notion, title: "Second", questions: 1,
                    statement_blocks: [ { "type" => "table", "headers" => headers, "rows" => [ %w[12 10 8 6 3 1] ] } ])

    assert_phone_fits "[data-statement-block=table] th", text: "Volleyball"
  end

  private

  def assert_phone_fits(selector, **options)
    with_mobile_viewport do
      visit sheet_page
      assert_selector selector, wait: 10, visible: :all, **options
      assert no_sideways_scroll?, "la page défile sur le côté : #{page.evaluate_script('document.documentElement.scrollWidth')} px"
    end
  end
end
