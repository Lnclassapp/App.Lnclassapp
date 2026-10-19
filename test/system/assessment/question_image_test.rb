require "application_system_test_case"

# ADR-0105 §4.4, UDR-0129 §3.2 et §3.4 : la question 2 attend son image, l'exercice refuse de se publier en la nommant ;
# l'équipe ajoute l'image dans la modale (la description devient son texte de remplacement), publie, et l'élève du niveau
# voit l'image au-dessus de l'énoncé, chargée à la demande et à ses dimensions.
class Assessment::QuestionImageTest < ApplicationSystemTestCase
  UPLOAD_WAIT = 20
  DESCRIPTION = "Une pile reliée à une lampe".freeze

  setup do
    @essential = create_essential(name: "Le circuit électrique")
    @exercise = create_exercise(essential: @essential, title: "Circuits", status: "draft", questions: 2)
    @second = @exercise.questions.order(:position).second
    @second.update!(content: "La lampe s'allume-t-elle ?", image_description: DESCRIPTION)
  end

  def t(key, **) = I18n.t(key, **)
  def questions = all("#exercise-questions > [data-teams--nested-form-target=list] > fieldset")

  def publish
    find("button[aria-controls=exercise-actions-menu]").click
    click_on t("catalog.content_status.actions.publish")
  end

  test "la question 2 attend son image ; ajoutée, l'exercice se publie et l'élève la voit au-dessus de l'énoncé" do
    sign_in_as create_team_member(team_role: "content")
    assert_current_path team_home_path
    visit exercise_path(@exercise.public_id)
    assert_selector "#exercise_header h1", text: "Circuits"

    assert_no_page_reload do
      publish
      assert_toast t("teams.exercises.transition.refusals.image_missing", number: 2)
      assert_equal "draft", @exercise.reload.status

      open_in_modal edit_teams_exercise_path(@exercise.public_id)
      within(questions[1]) do
        assert_text t("teams.exercises.question_fields.image_expected", description: DESCRIPTION)
        attach_file(file_fixture("photos/photo.jpg").to_s) { click_on t("teams.exercises.question_fields.add_image") }
        assert_selector "figure img[src^='/images/questions/']", wait: UPLOAD_WAIT
        assert_field t("teams.exercises.question_fields.image_alt_label"), with: DESCRIPTION
      end
      within("turbo-frame#modal dialog[open]") { click_on t("teams.exercises.edit.submit") }
      assert_toast t("teams.exercises.update.updated", title: "Circuits")
      assert_no_selector "turbo-frame#modal dialog"
    end

    visit exercise_path(@exercise.public_id)
    publish
    assert_toast t("teams.exercises.transition.published", title: "Circuits")
    assert_equal [ "published", DESCRIPTION ], [ @exercise.reload.status, Orm::QuestionImage.sole.alt ]
    sign_out

    student = create_student_for(@essential.course)
    session = create_exercise_session(student:, exercise: @exercise)
    create_attempt(session:, question: @exercise.questions.order(:position).first)
    sign_in_as student
    assert_current_path student_home_path
    visit exercise_session_path(session.public_id)

    within("#question-card") do
      image = find("img[alt='#{DESCRIPTION}'][loading=lazy][width='64'][height='48']")
      assert_text "La lampe s'allume-t-elle ?"
      page.document.synchronize { raise Capybara::ExpectationNotMet, "image non chargée" unless image.evaluate_script("this.naturalWidth") > 0 }
      assert image.evaluate_script("this.compareDocumentPosition(document.querySelector('#question-card legend')) & Node.DOCUMENT_POSITION_FOLLOWING")
    end
  end
end
