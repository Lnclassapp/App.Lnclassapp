require "test_helper"

# AS-05, TR-cadre-6, UDR-0006: the team publishes and archives an exercise; archiving destroys nothing. Since ADR-0113 §4.6
# the exercises come with the lesson import: no creation nor edition screen.
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
    { exercise: { title:, statement: "Lis bien.", exercise_type:, questions_attributes: questions }.compact }
  end

  # CA-29, ADR-0113 §4.6: the exercises come with the lesson import; no address is left to create or edit one: 404.
  test "CA-29: the creation and edition addresses of an exercise answer 404, even for the team, and nothing is written" do
    exercise = create_exercise(essential: @essential, status: "draft", title: "Méiose")
    sign_in_as @member

    get "/teams/essentials/#{@essential.slug}/exercises/new"
    assert_response :not_found
    post "/teams/essentials/#{@essential.slug}/exercises", params: exercise_params, as: :turbo_stream
    assert_response :not_found
    get "/teams/exercises/#{exercise.public_id}/edit"
    assert_response :not_found
    patch "/teams/exercises/#{exercise.public_id}", params: exercise_params, as: :turbo_stream
    assert_response :not_found

    assert_equal [ [ "Méiose", "draft" ] ], Orm::Exercise.pluck(:title, :status)
  end

  test "a teacher or a student receives 403 on every action, and nothing is written" do
    exercise = create_exercise(essential: @essential, status: "draft", title: "Méiose")

    [ create_teacher, create_student ].each do |user|
      sign_in_as user
      patch publish_teams_exercise_path(exercise.public_id), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_exercise_path(exercise.public_id), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ "Méiose", "draft" ] ], Orm::Exercise.pluck(:title, :status)
  end

  test "an unknown exercise cannot be published or archived" do
    sign_in_as @member

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

  # UDR-0130 §3: the refusal's exact value is set by the decision, so it is written out here.
  test "un exercice d'une fiche de révision en brouillon ne se publie pas : publiez d'abord ses parents" do
    orphan = create_exercise(essential: create_essential(status: "draft"), status: "draft")
    sign_in_as @member

    patch publish_teams_exercise_path(orphan.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including("Publiez d'abord la fiche de révision et sa fiche de cours.")
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

  # ADR-0105 §4.4, UDR-0129 §3.2 : la question 2 attend son image ; l'image envoyée se rattache à l'enregistrement.
  test "ADR-0105: a question waiting for its image blocks the publication, and names the question" do
    exercise = create_exercise(essential: @essential, status: "draft", questions: 2)
    exercise.questions.second.update!(image_description: "Un circuit simple")
    sign_in_as @member

    patch publish_teams_exercise_path(exercise.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.refusals.image_missing", number: 2))
    assert_equal "draft", exercise.reload.status
  end
end
