require "test_helper"

# CA-12, CA-13, CA-14, UDR-0006, UDR-0016: the team creates, edits, publishes and archives the essential sheets of a
# course, in a modal and Turbo Streams. The old application opened these actions to any signed-in account.
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

  test "a teacher or a student receives 403 on every action, and nothing is written" do
    essential = create_essential(course: @course, name: "La méiose", status: "draft")

    [ create_teacher, create_student ].each do |user|
      sign_in_as user

      get new_teams_course_essential_path(@course.slug)
      assert_response :forbidden
      post teams_course_essentials_path(@course.slug), params: essential_params, as: :turbo_stream
      assert_response :forbidden
      get edit_teams_essential_path(essential.slug)
      assert_response :forbidden
      patch teams_essential_path(essential.slug), params: essential_params(name: "Renommée"), as: :turbo_stream
      assert_response :forbidden
      patch publish_teams_essential_path(essential.slug), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_essential_path(essential.slug), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ "La méiose", "draft" ] ], Orm::Essential.pluck(:name, :status)
    assert_equal 0, Orm::AuditEvent.where(action: %w[content.published content.archived]).count
  end

  test "the creation form opens in the modal frame, with the course and the rich text editor, without attachment" do
    sign_in_as @member

    get new_teams_course_essential_path(@course.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal" do
      assert_select "link[rel=stylesheet][href*='/assets/trix']", 1
      assert_select "dialog#essential-modal #essential-course", text: tl("new.course", name: "Génétique et évolution")
      assert_select "form#essential-form[action='#{teams_course_essentials_path(@course.slug)}']" do
        assert_select "input[name='essential[name]'][maxlength='150'][required]"
        assert_select "input[name='essential[subtitle]'][maxlength='150']"
        assert_select "label[for=essential_content]", text: I18n.t("activemodel.attributes.dtos/catalog/essential_input.content")
        assert_select "[data-controller=rich-text-editor] trix-editor#essential_content[aria-describedby=essential_content_hint]"
        # ADR-0060: no direct upload address, the Active Storage routes are not drawn.
        assert_select "trix-editor#essential_content[data-direct-upload-url=''][data-blob-url-template='']"
        assert_select "input[type=hidden][name='essential[content]']", 1
        assert_select "input[type=file]", 0
      end
    end
    assert_select "button[type=submit][form=essential-form]", text: tl("new.submit")
  end

  test "a created essential is a draft at the end of its course, answered by a toast and a refresh of the host page" do
    create_essential(course: @course, name: "La méiose", position: 3)
    sign_in_as @member

    post teams_course_essentials_path(@course.slug), params: essential_params(name: "brassage GÉNÉTIQUE"), as: :turbo_stream

    essential = Orm::Essential.find_by!(name: "brassage GÉNÉTIQUE")
    assert_equal [ @course.id, "Par la méiose", "draft", 4, @member.id, nil ],
                 [ essential.course_id, essential.subtitle, essential.status, essential.position, essential.author_id,
                   essential.published_at ]
    assert_equal "<div><strong>À retenir</strong></div>", essential.content.body.to_html
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.created", name: "brassage GÉNÉTIQUE"))
    assert_select "turbo-stream[action=update][target=modal]", 1
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
  end

  test "an unknown course has no creation form, and receives no essential" do
    sign_in_as @member

    get new_teams_course_essential_path("inconnu")
    assert_response :not_found
    post teams_course_essentials_path("inconnu"), params: essential_params, as: :turbo_stream
    assert_response :not_found
    assert_equal 0, Orm::Essential.count
  end

  test "an invalid form reopens in the modal (422), with its errors and the values typed, content included" do
    sign_in_as @member

    post teams_course_essentials_path(@course.slug),
         params: essential_params(name: "", subtitle: "b" * 151, content: "<div><em>Gardé</em></div>"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#essential-modal[data-modal-target=dialog] form#essential-form" do
      assert_select "input[name='essential[name]'][aria-invalid=true]"
      assert_select "#essential_name_error", text: including(I18n.t("errors.messages.blank"))
      assert_select "input[name='essential[subtitle]'][value='#{'b' * 151}'][aria-invalid=true]"
      assert_select "input[type=hidden][name='essential[content]'][value='<div><em>Gardé</em></div>']"
    end
    assert_equal 0, Orm::Essential.count
  end

  test "two essentials of the same course cannot share a name; another course accepts it" do
    create_essential(course: @course, name: "Brassage génétique")
    other = create_course(name: "Biologie")
    sign_in_as @member

    post teams_course_essentials_path(@course.slug), params: essential_params, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "#essential_name_error", text: including(error_message(:name, :taken))

    post teams_course_essentials_path(other.slug), params: essential_params, as: :turbo_stream
    assert_response :success
    assert_equal 2, Orm::Essential.where(name: "Brassage génétique").count
  end

  test "an attachment or an image sent past the editor is refused on the content field" do
    sign_in_as @member

    post teams_course_essentials_path(@course.slug), params: essential_params(content: '<figure data-trix-attachment="{}"></figure>'),
                                                     as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "trix-editor#essential_content[aria-invalid=true][aria-describedby='essential_content_hint essential_content_error']"
    assert_select "#essential_content_error", text: including(error_message(:content, :attachment))
    assert_equal 0, Orm::Essential.count
  end

  test "without Turbo, a creation leads back to the course with a notice" do
    sign_in_as @member

    post teams_course_essentials_path(@course.slug), params: essential_params

    assert_redirected_to course_path(@course.slug)
    assert_equal tl("create.created", name: "Brassage génétique"), flash[:notice]
  end

  test "the edit form opens in the modal, filled in with the saved content, and shows the status" do
    essential = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions", status: "published",
                                 content: "<div><strong>Gras</strong><ul><li>Point</li></ul></div>")
    sign_in_as @member

    get edit_teams_essential_path(essential.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal link[rel=stylesheet][href*='/assets/trix']", 1
    assert_select "#essential-status", text: including(I18n.t("catalog.content_status.published"))
    assert_select "turbo-frame#modal form#essential-form[action='#{teams_essential_path(essential.slug)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[name='essential[name]'][value='La méiose']"
      assert_select "input[name='essential[subtitle]'][value='Deux divisions']"
      assert_select "input[type=hidden][name='essential[content]'][value*='<strong>Gras</strong><ul><li>Point</li></ul>']"
      assert_select "[data-controller=rich-text-editor] trix-editor#essential_content"
    end
    assert_select "button[type=submit][form=essential-form]", text: tl("edit.submit")
  end

  test "an unknown essential has no edit form, and cannot be updated, published or archived" do
    sign_in_as @member

    get edit_teams_essential_path("inconnue")
    assert_response :not_found
    patch teams_essential_path("inconnue"), params: essential_params, as: :turbo_stream
    assert_response :not_found
    patch publish_teams_essential_path("inconnue"), as: :turbo_stream
    assert_response :not_found
    patch archive_teams_essential_path("inconnue"), as: :turbo_stream
    assert_response :not_found
  end

  test "an update keeps the slug, the course, the position and the status, and answers by a toast and a refresh" do
    essential = create_essential(course: @course, name: "La méiose", status: "published", position: 2)
    slug = essential.slug
    sign_in_as @member

    patch teams_essential_path(slug), params: essential_params(name: "La Méiose", subtitle: ""), as: :turbo_stream

    assert_response :success
    essential.reload
    assert_equal [ "La Méiose", nil, slug, @course.id, 2, "published" ],
                 [ essential.name, essential.subtitle, essential.slug, essential.course_id, essential.position, essential.status ]
    assert_equal "<div><strong>À retenir</strong></div>", essential.content.body.to_html
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("update.updated", name: "La Méiose"))
    assert_select "turbo-stream[action=update][target=modal]", 1
    assert_select "turbo-stream[action=refresh]:not([request-id])", 1
  end

  test "an invalid update reopens the edit modal (422), and nothing changes" do
    essential = create_essential(course: @course, name: "La méiose")
    create_essential(course: @course, name: "La mitose")
    sign_in_as @member

    patch teams_essential_path(essential.slug), params: essential_params(name: "La mitose"), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal form#essential-form[action='#{teams_essential_path(essential.slug)}'] #essential_name_error",
                  text: including(error_message(:name, :taken))
    assert_equal "La méiose", essential.reload.name
  end

  test "without Turbo, an update leads back to the catalog with a notice" do
    essential = create_essential(course: @course, name: "La méiose")
    sign_in_as @member

    patch teams_essential_path(essential.slug), params: essential_params(name: "La Méiose")

    assert_redirected_to courses_path
    assert_equal tl("update.updated", name: "La Méiose"), flash[:notice]
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

  test "archiving keeps the exercises, their sessions and the assignments: nothing cascades" do
    essential = create_essential(course: @course, name: "La méiose")
    create_exercise_session(exercise: create_exercise(essential:))
    create_assignment(assignable: essential)
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
