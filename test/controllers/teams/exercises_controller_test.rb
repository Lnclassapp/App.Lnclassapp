require "test_helper"

# AS-03, AS-04, AS-05, TR-cadre-6, UDR-0006, UDR-0017: the team creates and edits an exercise with its questions in a
# large modal, publishes and archives it; archiving destroys nothing.
class Teams::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @essential = create_essential(name: "La méiose")
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tl(key, **) = I18n.t("teams.exercises.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def error_of(model, attribute, type) = I18n.t("activemodel.errors.models.dtos/assessment/#{model}.attributes.#{attribute}.#{type}")

  def answers(*pairs) = pairs.each_with_index.to_h { |(content, correct), index| [ index.to_s, { content:, correct: correct ? "1" : "0" } ] }

  # A true/false question and a single choice among 3: 2 questions, 5 answers (AS-03).
  def meiosis_questions
    { "0" => { content: "La méiose produit 4 cellules.", explanation: "Deux divisions.", question_type: "true_false",
               answers_attributes: answers([ "Vrai", true ], [ "Faux", false ]) },
      "1727000000000" => { content: "Combien de chromosomes ?", explanation: "", question_type: "single_choice",
                           answers_attributes: answers([ "23", true ], [ "46", false ], [ "92", false ]) } }
  end

  def exercise_params(title: "méiose et ADN", exercise_type: "evaluation", questions: meiosis_questions)
    { exercise: { title:, description: "Lis bien.", exercise_type:, questions_attributes: questions }.compact }
  end

  test "a teacher or a student receives 403 on every action, and nothing is written" do
    exercise = create_exercise(essential: @essential, status: "draft", title: "Méiose")

    [ create_teacher, create_student ].each do |user|
      sign_in_as user
      get new_teams_essential_exercise_path(@essential.slug)
      assert_response :forbidden
      post teams_essential_exercises_path(@essential.slug), params: exercise_params, as: :turbo_stream
      assert_response :forbidden
      get edit_teams_exercise_path(exercise.public_id)
      assert_response :forbidden
      patch teams_exercise_path(exercise.public_id), params: exercise_params, as: :turbo_stream
      assert_response :forbidden
      patch publish_teams_exercise_path(exercise.public_id), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_exercise_path(exercise.public_id), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ "Méiose", "draft" ] ], Orm::Exercise.pluck(:title, :status)
  end

  test "the creation form opens in the large modal, with templates to add questions and answers" do
    sign_in_as @member

    get new_teams_essential_exercise_path(@essential.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#exercise-modal.sm\\:max-w-2xl form#exercise-form[action='#{teams_essential_exercises_path(@essential.slug)}']" do
      assert_select "input[name='exercise[title]'][maxlength='150']"
      assert_select "select[name='exercise[exercise_type]'] option[selected][value=fixation]", text: tl("exercise_types.fixation")
      assert_select "section[data-controller='teams--nested-form'] [data-teams--nested-form-target=list] fieldset", 0
      assert_select "section > template[data-teams--nested-form-target=template]", 1
    end
    assert_select "#exercise-essential", text: including(@essential.name)
    assert_select "button[type=submit][form=exercise-form]", text: tl("new.submit")
    template = css_select("section > template").first.inner_html
    assert_includes template, "exercise[questions_attributes][NEW_QUESTION][answers_attributes][NEW_ANSWER][content]"
    assert_includes template, "exercise[questions_attributes][NEW_QUESTION][answers_attributes][0][correct]"
  end

  test "an unknown essential has no creation form" do
    sign_in_as @member

    get new_teams_essential_exercise_path("inconnue")
    assert_response :not_found
    post teams_essential_exercises_path("inconnue"), params: exercise_params, as: :turbo_stream
    assert_response :not_found
  end

  test "AS-03: the exercise, its 2 questions and 5 answers are saved as a draft, the title as typed; Turbo Stream answers" do
    sign_in_as @member

    post teams_essential_exercises_path(@essential.slug), params: exercise_params, as: :turbo_stream

    exercise = Orm::Exercise.sole
    assert_equal [ "méiose et ADN", "Lis bien.", "evaluation", "draft", @essential.id, @member.id ],
                 [ exercise.title, exercise.description, exercise.exercise_type, exercise.status, exercise.essential_id, exercise.author_id ]
    assert_equal [ [ 1, "true_false", "Deux divisions." ], [ 2, "single_choice", nil ] ],
                 exercise.questions.map { [ it.position, it.question_type, it.explanation ] }
    assert_equal [ [ "Vrai", true ], [ "Faux", false ], [ "23", true ], [ "46", false ], [ "92", false ] ],
                 exercise.questions.flat_map { |question| question.answers.map { [ it.content, it.correct ] } }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.created", title: "méiose et ADN"))
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
  end

  test "a question built wrong reopens the modal (422) with its error in place, and nothing is saved" do
    sign_in_as @member
    questions = meiosis_questions
    questions["1727000000000"][:answers_attributes] = answers([ "23", false ], [ "46", false ], [ "92", false ])

    post teams_essential_exercises_path(@essential.slug), params: exercise_params(questions:), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#exercise-modal form#exercise-form" do
      assert_select "[data-teams--nested-form-target=list] > fieldset[data-nested-question]", 2
      assert_select "[data-teams--nested-form-target=list] > fieldset:nth-of-type(2) [role=alert]",
                    text: including(error_of(:exercise_input, :questions, :wrong_correct_count))
      assert_select "[data-teams--nested-form-target=list] > fieldset:first-of-type [role=alert]", 0
      assert_select "input[name='exercise[questions_attributes][1][answers_attributes][2][content]'][value='92']"
      assert_select "input[name='exercise[title]'][value='méiose et ADN']"
    end
    assert_equal [ 0, 0, 0 ], [ Orm::Exercise.count, Orm::Question.count, Orm::Answer.count ]
  end

  test "blank fields are refused on their own field, in the modal" do
    sign_in_as @member
    questions = { "0" => { content: "", question_type: "single_choice", answers_attributes: answers([ "", true ], [ "B", false ]) } }

    post teams_essential_exercises_path(@essential.slug), params: exercise_params(title: "", questions:), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "#exercise_title_error", text: including(error_of(:exercise_input, :title, :blank))
    assert_select "#exercise_questions_error", text: including(error_of(:exercise_input, :questions, :invalid))
    assert_select "#exercise_questions_attributes_0_content_error", text: including(error_of(:question_input, :content, :blank))
    assert_select "#exercise_questions_attributes_0_answers_error", text: including(error_of(:question_input, :answers, :invalid))
    assert_select "input#exercise_questions_attributes_0_answers_attributes_0_content[aria-invalid=true]"
    assert_select "#exercise_questions_attributes_0_answers_attributes_0_content_error",
                  text: including(error_of(:answer_input, :content, :blank))
    assert_select "#exercise_questions_attributes_0_answers_attributes_1_content_error", 0
    assert_equal 0, Orm::Exercise.count
  end

  test "a title too long for the entity is refused on its field" do
    sign_in_as @member

    post teams_essential_exercises_path(@essential.slug), params: exercise_params(title: "a" * 151), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "#exercise_title_error", text: including(I18n.t("errors.messages.too_long", count: 150))
  end

  test "without Turbo, a creation or an update leads to the exercise with a notice" do
    sign_in_as @member

    post teams_essential_exercises_path(@essential.slug), params: exercise_params
    exercise = Orm::Exercise.sole
    assert_redirected_to exercise_path(exercise.public_id)
    assert_equal tl("create.created", title: "méiose et ADN"), flash[:notice]

    patch teams_exercise_path(exercise.public_id), params: exercise_params(title: "Méiose")
    assert_redirected_to exercise_path(exercise.public_id)
    assert_equal tl("update.updated", title: "Méiose"), flash[:notice]
  end

  test "the edit form is filled in, questions and correct answers included, and replaces a question (AS-04)" do
    exercise = create_exercise(essential: @essential, status: "draft", title: "Méiose", questions: 1)
    sign_in_as @member

    get edit_teams_exercise_path(exercise.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal form#exercise-form[action='#{teams_exercise_path(exercise.public_id)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[name='exercise[title]'][value='Méiose']"
      assert_select "textarea[name='exercise[questions_attributes][0][content]']", text: "<p>Question 1</p>"
      assert_select "input[type=checkbox][name='exercise[questions_attributes][0][answers_attributes][0][correct]'][checked]"
      assert_select "input[type=checkbox][name='exercise[questions_attributes][0][answers_attributes][1][correct]']:not([checked])"
    end
    assert_select "#questions-locked", 0

    patch teams_exercise_path(exercise.public_id), params: exercise_params(title: "Méiose"), as: :turbo_stream

    assert_response :success
    assert_equal [ "La méiose produit 4 cellules.", "Combien de chromosomes ?" ], exercise.reload.questions.map(&:content)
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("update.updated", title: "Méiose"))
    assert_select "turbo-stream[action=refresh]", 1
  end

  test "after a session, the questions are locked: read only, only title and description change (AS-04)" do
    exercise = create_exercise(essential: @essential, title: "Méiose", questions: 1)
    create_exercise_session(exercise:)
    sign_in_as @member

    get edit_teams_exercise_path(exercise.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_select "#questions-locked", text: including(tl("form.locked_title"))
    assert_select "#exercise-questions li", text: including("<p>Question 1</p>")
    assert_select "#exercise-questions svg[aria-label='#{tl('form.correct')}']", 1
    assert_select "form#exercise-form input[type=hidden][name='exercise[exercise_type]'][value=fixation]"
    assert_select "form#exercise-form [name^='exercise[questions_attributes]']", 0
    assert_select "template", 0

    patch teams_exercise_path(exercise.public_id),
          params: exercise_params(title: "Méiose II", exercise_type: "fixation", questions: nil), as: :turbo_stream
    assert_response :success
    assert_equal [ "Méiose II", [ "<p>Question 1</p>" ] ], [ exercise.reload.title, exercise.questions.map(&:content) ]

    patch teams_exercise_path(exercise.public_id), params: exercise_params(exercise_type: "fixation"), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "form#exercise-form [role=alert]", text: including(error_of(:exercise_input, :base, :questions_locked))
    assert_select "#questions-locked"
    assert_equal [ "<p>Question 1</p>" ], exercise.reload.questions.map(&:content)
  end

  test "an unknown exercise has no edit form and cannot be updated, published or archived" do
    sign_in_as @member

    get edit_teams_exercise_path("inconnu")
    assert_response :not_found
    patch teams_exercise_path("inconnu"), params: exercise_params, as: :turbo_stream
    assert_response :not_found
    patch publish_teams_exercise_path("inconnu"), as: :turbo_stream
    assert_response :not_found
    patch archive_teams_exercise_path("inconnu"), as: :turbo_stream
    assert_response :not_found
  end

  test "publishing answers in Turbo Stream: toast and status panel replaced, with an audit event" do
    exercise = create_exercise(essential: @essential, status: "draft", title: "Méiose")
    sign_in_as @member

    patch publish_teams_exercise_path(exercise.public_id), as: :turbo_stream

    assert_response :success
    assert_equal "published", exercise.reload.status
    assert_not_nil exercise.published_at
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("transition.published", title: "Méiose"))
    assert_select "turbo-stream[action=replace][target=content_status_exercise_#{exercise.public_id}]" do
      assert_select "#content_status_exercise_#{exercise.public_id}", text: including(I18n.t("catalog.content_status.published"))
    end
    assert_equal [ "content.published", @member.id, "Exercise", exercise.id ],
                 Orm::AuditEvent.pluck(:action, :actor_id, :subject_type, :subject_id).sole
  end

  test "an exercise without a question, or under a draft essential, is not published: error toast, 422" do
    empty = create_exercise(essential: @essential, status: "draft", questions: 0)
    orphan = create_exercise(essential: create_essential(status: "draft"), status: "draft")
    sign_in_as @member

    patch publish_teams_exercise_path(empty.public_id), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.refusals.not_publishable"))
    assert_select "turbo-stream[action=replace]", 0

    patch publish_teams_exercise_path(orphan.public_id), as: :turbo_stream
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("transition.refusals.parent_not_published"))
    assert_equal %w[draft draft], [ empty.reload.status, orphan.reload.status ]
  end

  test "TR-cadre-6: archiving keeps the sessions, their attempts and the badges; no route deletes an exercise (AS-05)" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    sessions = Array.new(3) { create_exercise_session(exercise:, status: "completed") }
    sessions.each { |session| create_attempt(session:) }
    2.times { |index| create_badge(exercise:, session: sessions[index], student: sessions[index].student) }
    sign_in_as @member

    patch archive_teams_exercise_path(exercise.public_id), as: :turbo_stream

    assert_response :success
    assert_equal "archived", exercise.reload.status
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("transition.archived", title: "Méiose"))
    assert_equal [ 1, 2, 8, 3, 3, 2 ], [ Orm::Exercise.count, Orm::Question.count, Orm::Answer.count, Orm::ExerciseSession.count,
                                         Orm::QuestionAttempt.count, Orm::ExerciseBadge.count ]
    assert_equal [ "content.archived", exercise.id ], Orm::AuditEvent.pluck(:action, :subject_id).sole
    assert_empty Rails.application.routes.routes.select { it.verb == "DELETE" && it.defaults[:controller].to_s.include?("exercises") }
  end

  test "without Turbo, a transition leads to the exercise with a notice, or the reason of the refusal" do
    exercise = create_exercise(essential: @essential, title: "Méiose")
    sign_in_as @member

    patch archive_teams_exercise_path(exercise.public_id)
    assert_redirected_to exercise_path(exercise.public_id)
    assert_equal tl("transition.archived", title: "Méiose"), flash[:notice]

    patch archive_teams_exercise_path(exercise.public_id)
    assert_redirected_to exercise_path(exercise.public_id)
    assert_equal tl("transition.refusals.transition_not_allowed"), flash[:alert]
  end
end
