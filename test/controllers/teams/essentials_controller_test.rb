require "test_helper"

# UDR-0006: the team publishes (alone or with its exercises) and archives the notions of a lesson, in Turbo Streams. The
# old application opened these actions to any signed-in account. Since ADR-0113 §4.6 it no longer creates nor edits them.
class Teams::EssentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @course = create_course(name: "Génétique et évolution")
  end

  def essential_params(name: "Brassage génétique", subtitle: "Par la méiose", content: "<div><strong>À retenir</strong></div>")
    { essential: { name:, subtitle:, content: } }
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tl(key, **) = I18n.t("teams.essentials.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def error_message(field, kind) = I18n.t("activemodel.errors.models.dtos/catalog/essential_input.attributes.#{field}.#{kind}")

  # CA-29, ADR-0113 §4.6: the team no longer writes a notion on screen; it imports the lesson. No address is left to create or
  # edit one, whoever asks: 404.
  test "CA-29: the creation and edition addresses of a notion answer 404, even for the team, and nothing is written" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")
    sign_in_as @member

    get "/teams/courses/#{@course.slug}/essentials/new"
    assert_response :not_found
    post "/teams/courses/#{@course.slug}/essentials", params: essential_params, as: :turbo_stream
    assert_response :not_found
    get "/teams/essentials/#{essential.slug}/edit"
    assert_response :not_found
    patch "/teams/essentials/#{essential.slug}", params: essential_params(name: "Renommée"), as: :turbo_stream
    assert_response :not_found

    assert_equal [ [ "La méiose", "draft" ] ], Orm::Essential.pluck(:name, :status)
  end

  test "a teacher or a student receives 403 on every action, and nothing is written" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")

    [ create_teacher, create_student ].each do |user|
      sign_in_as user

      patch publish_teams_essential_path(essential.slug), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_essential_path(essential.slug), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ "La méiose", "draft" ] ], Orm::Essential.pluck(:name, :status)
    assert_equal 0, Orm::AuditEvent.where(action: %w[content.published content.archived]).count
  end

  test "an unknown essential cannot be published or archived" do
    sign_in_as @member

    patch publish_teams_essential_path("inconnue"), as: :turbo_stream
    assert_response :not_found
    patch archive_teams_essential_path("inconnue"), as: :turbo_stream
    assert_response :not_found
  end

  test "publishing a draft of a published course replaces its status panel, and is journaled" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal "published", essential.reload.status
    assert_not_nil essential.published_at
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("transition.published", name: "La méiose"))
    assert_select "turbo-stream[action=replace][target=content_status_essential_#{essential.slug}] " \
                  "#content_status_essential_#{essential.slug}", text: including(I18n.t("catalog.content_status.published"))
    assert_select "turbo-stream[action=replace][target=content_transitions_essential_#{essential.slug}] " \
                  "#content_transitions_essential_#{essential.slug}" do
      assert_select "a[data-turbo-method=patch][href='#{archive_teams_essential_path(essential.slug)}']", 1
      assert_select "a[href='#{publish_teams_essential_path(essential.slug)}']", 0
    end
    assert_equal [ "content.published", @member.id, "Essential", essential.id ],
                 Orm::AuditEvent.where(action: "content.published").pick(:action, :actor_id, :subject_type, :subject_id)
  end

  test "publishing an essential of a draft course is refused (422) with the reason, and nothing changes" do
    essential = create_essential(course: create_course(status: "draft"), status: "draft")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.refused_title.publish"))
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.parent_not_published"))
    assert_select "turbo-stream[action=replace]", 0
    assert_equal "draft", essential.reload.status
  end

  # UDR-0130 §3 (error state): the refusal's exact value is set by the decision, so it is written out here.
  test "la fiche de révision d'une fiche de cours en brouillon ne se publie pas, et le refus le dit" do
    essential = create_essential(course: create_course(status: "draft"), status: "draft")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]",
                  text: including("La fiche de cours de cette fiche de révision n'est pas publiée : publiez d'abord la fiche de cours.")
  end

  test "archiving keeps the exercises, their sessions and the assignments: nothing cascades" do
    essential = create_essential(course: @course, name: "La méiose")
    exercise = create_exercise(essential:)
    create_exercise_session(exercise:)
    create_assignment(assignable: exercise)
    sign_in_as @member

    patch archive_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal "archived", essential.reload.status
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("transition.archived", name: "La méiose"))
    assert_select "turbo-stream[action=replace][target=content_transitions_essential_#{essential.slug}] " \
                  "a[data-turbo-method=patch][href='#{publish_teams_essential_path(essential.slug)}']", 1
    assert_equal [ 1, 1, 1 ], [ Orm::Exercise.count, Orm::ExerciseSession.count, Orm::ClassroomAssignment.count ]
    assert_equal 1, Orm::AuditEvent.where(action: "content.archived", subject_id: essential.id).count
  end

  test "archiving a draft is refused (422)" do
    essential = create_essential(course: @course, status: "draft")
    sign_in_as @member

    patch archive_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.refused_title.archive"))
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.transition_not_allowed"))
  end

  test "without Turbo, a transition leads back to the page of the button, with a notice or the reason of the refusal" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")
    blocked = create_essential(course: create_course(status: "draft"), status: "draft")
    sign_in_as @member

    patch publish_teams_essential_path(essential.slug), headers: { "Referer" => course_essential_url(@course.slug, essential.slug) }
    assert_redirected_to course_essential_url(@course.slug, essential.slug)
    assert_equal tl("transition.published", name: "La méiose"), flash[:notice]

    patch archive_teams_essential_path(essential.slug)
    assert_redirected_to courses_path
    assert_equal tl("transition.archived", name: "La méiose"), flash[:notice]

    patch publish_teams_essential_path(blocked.slug)
    assert_redirected_to courses_path
    assert_equal tl("transition.parent_not_published"), flash[:alert]
  end

  # ADR-0035, amendement du 2026-10-01 : « Tout publier » depuis le menu ⋮ de la fiche.
  def cascade(key, **) = I18n.t("teams.publish_cascade.#{key}", **)

  test "« Tout publier » publishes the sheet and its complete draft exercises, not the other sheets of the course" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")
    other = create_essential(course: @course, status: "draft")
    exercises = Array.new(2) { create_exercise(essential:, status: "draft") }
    archived = create_exercise(essential:, status: "archived")
    sign_in_as @member

    patch publish_all_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :success
    assert_equal %w[published draft published published archived], [ essential, other, *exercises, archived ].map { it.reload.status }
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(cascade("done.essential", name: "La méiose", exercises: cascade("exercises", count: 2)))
    assert_select "turbo-stream[action=refresh]", 1
  end

  test "« Tout publier » on a sheet of a draft course is refused in 422 with the reason, and nothing changes" do
    essential = create_essential(course: create_course(status: "draft"), status: "draft")
    exercise = create_exercise(essential:, status: "draft")
    sign_in_as @member

    patch publish_all_teams_essential_path(essential.slug), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tl("transition.parent_not_published"))
    assert_select "turbo-stream[action=refresh]", 0
    assert_equal %w[draft draft], [ essential, exercise ].map { it.reload.status }

    patch publish_all_teams_essential_path(essential.slug)
    assert_redirected_to courses_path
    assert_equal tl("transition.parent_not_published"), flash[:alert]
  end
end
