require "application_system_test_case"

# Chantier fiche-listes-formules : dans « Je m'entraîne » de la fiche, une proposition en formule d'un menu (choix dans une liste, étapes à
# remettre dans l'ordre, éléments à relier) restait en LaTeX brut. Le menu propose des lettres, les propositions se lisent rendues (UDR-0183).
class Catalog::PracticeFormulasInListsTest < ApplicationSystemTestCase
  SELECT = { "content" => "Complète : $e^{x} = 7 \\iff x =$ ___", "question_type" => "select", "explanation" => PracticeHelper::EXPLANATION,
             "answers" => [ { "content" => "$e^{7}$", "correct" => false, "blank" => 0 }, { "content" => "$\\ln 7$", "correct" => true, "blank" => 0 } ] }.freeze
  ORDERING = { "content" => "Range les étapes.", "question_type" => "ordering", "explanation" => PracticeHelper::EXPLANATION,
               "answers" => [ { "content" => "$e^x = 7$" }, { "content" => "$x = \\ln 7$" }, { "content" => "$S = \\{\\ln 7\\}$" } ] }.freeze
  MATCHING = { "content" => "Relie.", "question_type" => "matching", "explanation" => PracticeHelper::EXPLANATION,
               "answers" => [ { "content" => "$e^{\\ln 2}$", "match" => "$2$" }, { "content" => "$e^0$", "match" => "$1$" } ] }.freeze

  setup do
    @course = create_course(name: "Exponentielle", content: "", sheet_theme: "teal")
    @student = create_student_for(@course)
    @notion = create_practice_notion(course: @course, questions: [ SELECT, ORDERING, MATCHING ])
  end

  test "les propositions en formule des menus se lisent rendues, jamais en LaTeX brut, et la réponse se juge" do
    sign_in_as @student

    with_mobile_viewport do
      visit course_fiche_path(@course.slug)

      within "turbo-frame#practice_#{@notion.slug}" do
        assert_selector "[data-option-value] .katex", minimum: 2 + 3 + 2
        options = all("option", visible: :all).map(&:text)
        assert(options.none? { it.include?("$") || it.include?("\\") }, "options en LaTeX brut : #{options.inspect}")

        pick("answers[0][blanks][0]", "\\ln 7")
        click_button I18n.t("catalog.revision_sheets.practice.check")
        assert_selector "#practice-#{@notion.slug}-q1 .sheet-verdict[data-verdict=correct]"
      end
    end
  end

  test "une liste de mots garde ses libellés dans le menu" do
    notion = create_practice_notion(course: create_course(name: "Thalès", content: "", level: @course.level), questions: [ select_question ])
    sign_in_as @student
    visit course_fiche_path(notion.course.slug)

    within "turbo-frame#practice_#{notion.slug}" do
      assert_selector "option", text: "juste 0", visible: :all
      assert_no_selector "[data-option-value]"
    end
  end

  private

  # La proposition rendue dont l'annotation TeX vaut `tex`, puis l'option de même valeur dans le menu `name`.
  def pick(name, tex)
    menu = find("select[name='#{name}']")
    shown = all("##{menu[:id]}-propositions [data-option-value]").find { it.find("annotation", visible: :all).text(:all) == tex }
    assert shown, "proposition #{tex} introuvable"
    menu.find("option[value='#{shown["data-option-value"]}']", visible: :all).select_option
  end
end
