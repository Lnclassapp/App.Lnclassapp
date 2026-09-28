require "application_system_test_case"

# CA-11, AS-37 — UDR-0015. The student opens a published essential sheet: its content and formulas, then each published
# exercise with his badge (« Or » at 80 %), and « Commencer » takes him to the first question (Turbo Drive). The team
# opens « Nouvel exercice » and « Modifier » from the sheet, in the modal: the streams of lots B5 and B4 refresh the
# sheet by morphing, the new exercise and the content typed in Trix rendered on it, without a page reload.
class Catalog::EssentialPageTest < ApplicationSystemTestCase
  # The team home belongs to a later lot: until it is merged, a stand-in answers where the sign-in lands.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) do
      def show = render(html: "home", layout: true, formats: :html)
    end)
  end

  # The content as the rich text editor of lot B4 writes it: bold, a list and a formula.
  CONTENT = "<div>Une phrase<br><strong>Gras</strong> et $2^n$ combinaisons.</div><ul><li>Premier point</li></ul>".freeze

  setup do
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course: @course, name: "La méiose", content: CONTENT)
    @exercise = create_exercise(essential: @essential, title: "Méiose et ADN", position: 1)
    create_exercise(essential: @essential, title: "Brouillon caché", status: "draft", position: 2)
  end

  def scope = "catalog.essentials"
  def page_path = course_essential_path(@course.slug, @essential.slug)
  def texercise(key, **) = I18n.t("teams.exercises.#{key}", **)
  def questions = all("#exercise-questions > [data-teams--nested-form-target=list] > fieldset")

  def expect_morph
    page.execute_script("window.lnclassMorphed = false; addEventListener('turbo:morph', () => window.lnclassMorphed = true, { once: true })")
  end

  def assert_morphed
    page.document.synchronize { raise Capybara::ExpectationNotMet, "pas de morphing" unless page.evaluate_script("window.lnclassMorphed") }
  end

  def assert_rich_content
    within "#essential_content" do
      assert_selector "strong", text: "Gras"
      assert_selector "ul li", text: "Premier point"
      assert_selector ".katex", count: 1
    end
  end

  test "the student sees the content, his gold badge at 80 %, and « Commencer » opens the first question" do
    student = create_student
    best = create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 80)
    create_badge(student:, exercise: @exercise, level: "gold", session: best)
    sign_in_as student

    visit page_path

    assert_selector "#essential_header h1", text: "La méiose"
    assert_rich_content
    assert_no_text "Brouillon caché"
    within "#essential_exercise_#{@exercise.public_id}" do
      assert_text I18n.t("#{scope}.exercise_progress.badge", level: "Or")
      assert_text I18n.t("#{scope}.exercise_progress.best_score", score: 80)
      click_on I18n.t("#{scope}.exercise_progress.start")
    end

    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_text "Question 1"
  end

  test "on a phone, the student's sheet fits the width" do
    sign_in_as create_student

    with_mobile_viewport do
      visit page_path

      assert_selector "#essential_exercises button", text: I18n.t("#{scope}.exercise_progress.start")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  test "the team creates an exercise then renames the sheet from the sheet, without a page reload" do
    sign_in_as create_team_member
    assert_current_path team_home_path
    visit page_path
    assert_rich_content
    assert_selector "#essential_exercises li", count: 2

    assert_no_page_reload do
      click_on I18n.t("#{scope}.show.new_exercise")
      within "turbo-frame#modal dialog[open]" do
        fill_in "exercise[title]", with: "Anomalies de la méiose"
        click_on texercise("form.add_question")
        within(questions.first) do
          find("textarea[name$='[content]']").fill_in with: "La trisomie 21 est une anomalie."
          find("select[name$='[question_type]']").select texercise("question_types.true_false")
          (2 - all("[data-nested-answer]").size).times { click_on texercise("question_fields.add_answer") }
          [ [ "Vrai", true ], [ "Faux", false ] ].each_with_index do |(text, correct), rank|
            within(all("[data-nested-answer]")[rank]) do
              find("input[type=text]").fill_in with: text
              find("input[type=checkbox]").set(correct)
            end
          end
        end
        expect_morph
        click_on texercise("new.submit")
      end

      assert_morphed
      assert_toast texercise("create.created", title: "Anomalies de la méiose")
      assert_no_selector "turbo-frame#modal dialog"
      exercise = Orm::Exercise.find_by!(title: "Anomalies de la méiose")
      within "#essential_exercise_#{exercise.public_id}" do
        assert_link "Anomalies de la méiose"
        assert_text I18n.t("catalog.content_status.draft")
      end
      assert_selector "#essential_exercises li", count: 3
      assert_rich_content

      click_menu_action("#essential_team_actions", I18n.t("#{scope}.show.edit"))
      within "turbo-frame#modal dialog[open]" do
        fill_in "essential[name]", with: "La méiose et ses anomalies"
        expect_morph
        click_on I18n.t("teams.essentials.edit.submit")
      end

      assert_morphed
      assert_toast I18n.t("teams.essentials.update.updated", name: "La méiose et ses anomalies")
      assert_selector "#essential_header h1", text: "La méiose et ses anomalies"
      assert_rich_content
    end
  end
end
