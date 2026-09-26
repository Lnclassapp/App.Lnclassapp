require "application_system_test_case"

# AS-03, AS-04, UDR-0006, UDR-0017: the team writes an exercise, its questions and their answers in the large modal,
# adds and removes them without a request, and neither creating nor editing reloads the page.
class Teams::ExerciseFormTest < ApplicationSystemTestCase
  # The team home and the essential screen belong to other lots: until they are merged, a stand-in answers where the
  # sign-in lands, as in test/system/teams/materials_test.rb, and the form opens in the modal frame from there.
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @essential = create_essential(name: "La méiose")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def tl(key, **) = I18n.t("teams.exercises.#{key}", **)
  def questions = all("#exercise-questions > [data-teams--nested-form-target=list] > fieldset")

  # The host page belongs to another lot: the stream refreshes it by morphing. The next step waits for that morph.
  def expect_morph
    page.execute_script("window.lnclassMorphed = false; addEventListener('turbo:morph', () => window.lnclassMorphed = true, { once: true })")
  end

  def assert_morphed
    page.document.synchronize { raise Capybara::ExpectationNotMet, "pas de morphing" unless page.evaluate_script("window.lnclassMorphed") }
  end

  def submit_modal(label)
    within("turbo-frame#modal dialog[open]") { click_on label }
  end

  # Fills the question at index with its statement, its type and one answer per pair (text, correct).
  def fill_question(index, content, type, *pairs)
    within(questions[index]) do
      find("textarea[name$='[content]']").fill_in with: content
      find("select[name$='[question_type]']").select tl("question_types.#{type}")
      (pairs.size - all("[data-nested-answer]").size).times { click_on tl("question_fields.add_answer") }
      pairs.each_with_index do |(text, correct), rank|
        within(all("[data-nested-answer]")[rank]) do
          find("input[type=text]").fill_in with: text
          find("input[type=checkbox]").set(correct)
        end
      end
    end
  end

  test "AS-03: two questions and five answers added with the buttons, a wrong one fixed in the modal, then edited" do
    assert_no_page_reload do
      open_in_modal new_teams_essential_exercise_path(@essential.slug)
      assert_selector "#exercise-essential", text: "La méiose"
      fill_in "exercise[title]", with: "méiose et ADN"

      3.times { click_on tl("form.add_question") }
      assert_equal 3, questions.size
      within(questions.last) { find("button[aria-label='#{tl("question_fields.remove")}']").click }
      assert_equal 2, questions.size

      fill_question 0, "La méiose produit 4 cellules.", "true_false", [ "Vrai", true ], [ "Faux", false ]
      fill_question 1, "Combien de chromosomes ?", "single_choice", [ "23", false ], [ "46", false ], [ "92", false ]
      submit_modal tl("new.submit")

      assert_selector "#exercise-questions > [data-teams--nested-form-target=list] > fieldset:nth-of-type(2) [role=alert]",
                      text: I18n.t("activemodel.errors.models.dtos/assessment/exercise_input.attributes.questions.wrong_correct_count")
      assert_no_selector "#exercise-questions > [data-teams--nested-form-target=list] > fieldset:first-of-type [role=alert]"
      assert_field "exercise[title]", with: "méiose et ADN"
      within(questions[1]) { within(all("[data-nested-answer]")[0]) { find("input[type=checkbox]").check } }
      expect_morph
      submit_modal tl("new.submit")

      assert_morphed
      assert_toast tl("create.created", title: "méiose et ADN")
      assert_no_selector "turbo-frame#modal dialog"

      exercise = Orm::Exercise.sole
      assert_equal [ 2, 5 ], [ exercise.questions.count, Orm::Answer.count ]

      open_in_modal edit_teams_exercise_path(exercise.public_id)
      assert_field "exercise[title]", with: "méiose et ADN"
      assert_equal 2, questions.size
      fill_in "exercise[title]", with: "Méiose"
      expect_morph
      submit_modal tl("edit.submit")

      assert_morphed
      assert_toast tl("update.updated", title: "Méiose")
      assert_no_selector "turbo-frame#modal dialog"
      assert_equal "Méiose", exercise.reload.title
    end
  end

  test "on a phone, the large modal and its questions never make the page scroll sideways" do
    with_mobile_viewport do
      open_in_modal new_teams_essential_exercise_path(@essential.slug)
      click_on tl("form.add_question")
      within(questions.first) { click_on tl("question_fields.add_answer") }

      assert_selector "#exercise-questions [data-nested-answer]", count: 3
      assert_equal page.evaluate_script("document.documentElement.clientWidth"),
                   page.evaluate_script("document.documentElement.scrollWidth")
      assert page.evaluate_script("document.querySelector('#exercise-form').scrollWidth <= document.querySelector('#exercise-form').clientWidth")
    end
  end
end
