require "test_helper"

module Catalog
  # CA-3 — ADR entraînement corrigé sans trace §4 : la page de la fiche ne contient ni la bonne réponse, ni l'explication, ni `correct`, ni
  # le bouton « Correction » ; un ordre ou un relier n'y est pas dans l'ordre de sa solution.
  class PracticeLeakTest < ActionView::TestCase
    helper ComponentsHelper, Catalog::SheetTextHelper, Assessment::BlanksHelper

    def lesson(*questions)
      course = create_course(name: "Racines carrées", content: "")
      create_practice_notion(course:, questions:)
      Queries::Catalog::RevisionSheetQuery.new.call(course_slug: course.slug, actor: nil).sheet
    end

    def render_sheet(*questions)
      render(partial: "catalog/revision_sheets/sheet", locals: { sheet: lesson(*questions), cut: nil })
      rendered
    end

    test "CA-3: the page carries the statement, the boxes and the choices but no answer, no explanation and no verdict" do
      html = render_sheet(numeric_question, fill_blank_question, choice_question, ordering_question, matching_question, written_question,
                          { "content" => "Le ___ est opposé à l'angle droit.", "question_type" => "select", "explanation" => PracticeHelper::EXPLANATION,
                            "answers" => [ { "content" => "côté", "correct" => true }, { "content" => "sommet", "correct" => false } ] })

      assert_select "turbo-frame[id^=practice_] form[action*='practice_check'] input[name=digest][type=hidden]"
      assert_select "input[name='answers[0][blanks][0]']"
      assert_select "select[name='answers[6][blanks][0]'] option", 3
      assert_select "input[type=radio][name='answers[2][ids][]']", 3
      assert_select "button", text: I18n.t("catalog.revision_sheets.practice.check")
      [ PracticeHelper::EXPLANATION, "4,8", "hypoténuse", "data-verdict", "sheet-practice-correction", "aria-invalid", "checked",
        I18n.t("catalog.revision_sheets.practice.correction") ].each do |secret|
        assert_not_includes html, secret
      end
      assert_no_match(/correct/i, html.gsub(/Correction/i, "").sub(/Corrig/i, ""))
    end

    test "CA-3: the solution of an ordering or a matching is not given in its order, and no position nor identifier is in the page" do
      html = render_sheet(ordering_question, matching_question)
      doc = Nokogiri::HTML.fragment(html)
      ordering_options = doc.css("select[name='answers[0][order][]']").first.css("option").map(&:text).reject { it.blank? || it == I18n.t("catalog.revision_sheets.practice.choose") }
      matching_options = doc.css("select[name='answers[1][order][]']").first.css("option").map(&:text).reject { it.blank? || it == I18n.t("catalog.revision_sheets.practice.choose") }

      assert_not_equal %w[Décomposer Séparer Calculer], ordering_options
      assert_not_equal %w[3 4 5], matching_options
      assert_equal %w[3 4 5], matching_options.sort
      assert_equal [ "0", "1", "2" ], doc.css("select[name='answers[0][order][]'] option").filter_map { it["value"].presence }.first(3).sort
    end

    test "the hint is in the page, a notion without practice has no block at all" do
      render_sheet(two_blank_numeric_question)

      assert_select "details.sheet-practice-hint p", text: "Écris l'égalité des trois rapports."
      assert_select "details.sheet-practice-hint summary", text: I18n.t("catalog.revision_sheets.practice.hint")
    end
  end
end
