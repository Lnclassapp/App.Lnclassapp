require "application_system_test_case"

# rendu-lecons-v3-390 : à 390 px, une formule KaTeX trop large défile dans son propre cadre, jamais la page. Trois endroits qui
# débordaient : la fiche de révision, le « À retenir » d'une feuille « Prépare interros » et le libellé d'une question.
class Catalog::LongFormulasTest < ApplicationSystemTestCase
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

  def no_sideways_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")

  def displays_fit?
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".katex-display")].every((el) => el.getBoundingClientRect().right <= window.innerWidth + 1)
    JS
  end

  test "on a phone a long display formula scrolls in its own frame, never the page" do
    with_mobile_viewport do
      visit course_path(@course.slug)
      assert_selector ".ps-remember .katex-display", wait: 10
      assert_selector ".ps-question-label .katex-display"
      assert_selector ".sheet-text .katex-display"
      assert no_sideways_scroll?, "la page défile sur le côté"
      assert displays_fit?, "une formule dépasse l'écran"
    end
  end
end
