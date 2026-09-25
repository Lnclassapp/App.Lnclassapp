require "test_helper"

# CA-05, CA-06, CA-07, UDR-0006, UDR-0014: the team creates and edits a course in a modal (rich text editor), then
# publishes and archives it from its status panel — Turbo Stream writes, 422 in the modal, HTML fallback.
class Teams::CoursesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @tle = create_level(name: "Tle", position: 7)
    @second = create_level(name: "2nde", position: 5)
    @d = create_series(name: "D")
    @c = create_series(name: "C")
    link_level_series(level: @tle, series: @d)
    link_level_series(level: @second, series: @c)
    @svt = create_material(name: "SVT", shortname: "SVT")
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tc(key, **) = I18n.t("teams.courses.#{key}", **)
  def error(field, kind) = I18n.t("activemodel.errors.models.dtos/catalog/course_input.attributes.#{field}.#{kind}")
  def including(text) = /#{Regexp.escape(text)}/

  def course_params(name: "génétique et évolution", subtitle: "Du gène à l'espèce", level_slug: "tle", series_slug: "d",
                    material_slug: "svt", content: "<div><strong>ADN</strong></div><ul><li>Gène</li></ul>")
    { course: { name:, subtitle:, level_slug:, series_slug:, material_slug:, content: } }
  end

  test "a student or a teacher receives 403 on every action, and nothing is written" do
    course = create_course(name: "Optique", level: @tle, material: @svt, status: "draft")

    [ create_student, create_teacher ].each do |outsider|
      sign_in_as outsider

      get new_teams_course_path
      assert_response :forbidden
      get edit_teams_course_path(course.slug)
      assert_response :forbidden
      post teams_courses_path, params: course_params, as: :turbo_stream
      assert_response :forbidden
      patch teams_course_path(course.slug), params: course_params(name: "Autre"), as: :turbo_stream
      assert_response :forbidden
      patch publish_teams_course_path(course.slug), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_course_path(course.slug), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ "Optique", "draft" ] ], Orm::Course.pluck(:name, :status)
    assert_empty Orm::AuditEvent.where(action: %w[content.published content.archived])
  end

  test "the new form opens in the modal frame, with the rich text editor and the series filed under their level" do
    sign_in_as @member

    get new_teams_course_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog form#course-form[action='#{teams_courses_path}'][method=post]"
    assert_select "link[rel=stylesheet][href*=trix]"
    assert_select "input[name='course[name]'][maxlength='200'][required]"
    assert_select "input[name='course[subtitle]'][maxlength='150']:not([required])"
    assert_select "select[name='course[level_slug]'] option", text: "Tle"
    assert_select "select[name='course[series_slug]'] > option[value='']", text: tc("form.no_series")
    assert_select "select[name='course[series_slug]'] optgroup[label=Tle] option[value=d]", text: "D"
    assert_select "select[name='course[series_slug]'] optgroup[label=Tle] option", 1
    assert_select "select[name='course[series_slug]'] optgroup[label='2nde'] option[value=c]"
    assert_select "select[name='course[material_slug]'] option[value=svt]"
    assert_select "[data-controller=rich-text-editor] trix-editor#course_content[input]"
    assert_select "input[type=hidden][name='course[content]']"
    assert_select "button[type=submit][form=course-form]", text: tc("new.submit")
    assert_select "select[name='course[status]']", 0
  end

  test "a created course is a draft by the signed-in member, its name kept as typed, answered in Turbo Stream" do
    sign_in_as @member

    post teams_courses_path, params: course_params, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    course = Orm::Course.sole
    assert_equal [ "génétique et évolution", "genetique-et-evolution", "draft", @member.id, nil ],
                 [ course.name, course.slug, course.status, course.author_id, course.published_at ]
    assert_equal [ @tle.id, @d.id, @svt.id ], [ course.level_id, course.series_id, course.material_id ]
    assert_includes course.content.body.to_html, "<strong>ADN</strong>"
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("create.created", name: course.name))
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]:not([request-id])"
  end

  test "an invalid entry reopens the modal in 422 with its errors and the typed values" do
    sign_in_as @member

    post teams_courses_path, params: course_params(name: "  ", material_slug: "")

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal #course_name_error", text: error(:name, :blank)
    assert_select "#course_material_slug_error", text: error(:material_slug, :blank)
    assert_select "select[name='course[level_slug]'] option[selected][value=tle]"
    assert_select "select[name='course[series_slug]'] option[selected][value=d]"
    assert_select "input[type=hidden][name='course[content]'][value=?]", "<div><strong>ADN</strong></div><ul><li>Gène</li></ul>"
    assert_equal 0, Orm::Course.count
  end

  test "a series closed to the level, or a name taken in the same level, series and subject, is refused in 422" do
    create_course(name: "Génétique", level: @tle, series: @d, material: @svt)
    sign_in_as @member

    post teams_courses_path, params: course_params(series_slug: "c")
    assert_response :unprocessable_entity
    assert_select "#course_series_slug_error", text: error(:series_slug, :not_allowed)

    post teams_courses_path, params: course_params(name: "Génétique")
    assert_response :unprocessable_entity
    assert_select "#course_name_error", text: error(:name, :taken)
    assert_equal 1, Orm::Course.count
  end

  test "without Turbo, a created course leads to its page" do
    sign_in_as @member

    post teams_courses_path, params: course_params(name: "Optique")

    assert_redirected_to course_path("optique")
    assert_equal tc("create.created", name: "Optique"), flash[:notice]
  end

  test "the edit form reloads the saved course, content included, and shows its status" do
    course = create_course(name: "Génétique", subtitle: "Du gène", level: @tle, series: @d, material: @svt,
                           content: "<div><strong>ADN</strong></div>")
    sign_in_as @member

    get edit_teams_course_path(course.slug), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog form#course-form[action='#{teams_course_path(course.slug)}'] input[name=_method][value=patch]"
    assert_select "input[name='course[name]'][value=Génétique]"
    assert_select "input[name='course[subtitle]'][value='Du gène']"
    assert_select "select[name='course[level_slug]'] option[selected][value=tle]"
    assert_select "select[name='course[series_slug]'] option[selected][value=d]"
    assert_select "select[name='course[material_slug]'] option[selected][value=svt]"
    assert_select "input[type=hidden][name='course[content]'][value*='<strong>ADN</strong>']"
    assert_select "dialog", text: including(I18n.t("catalog.content_status.published"))
  end

  test "a course without series is edited with « Aucune série »; an unknown course is not found" do
    course = create_course(name: "Philo", level: @tle, material: @svt)
    sign_in_as @member

    get edit_teams_course_path(course.slug)
    assert_response :success
    assert_select "select[name='course[series_slug]'] option[selected]", 0

    get edit_teams_course_path("inconnu")
    assert_response :not_found
  end

  test "an updated course keeps its slug, status and author, and asks the host page to refresh" do
    author = create_team_member(second_factor: false)
    course = create_course(name: "Génétique", level: @tle, series: @d, material: @svt, author:, status: "draft")
    sign_in_as @member

    patch teams_course_path(course.slug), params: course_params(name: "Génétique et évolution", series_slug: "",
                                                                  level_slug: "2nde", content: "<div>Nouveau</div>"),
                                          as: :turbo_stream

    assert_response :success
    course.reload
    assert_equal [ "Génétique et évolution", "genetique", "draft", author.id, @second.id, nil ],
                 [ course.name, course.slug, course.status, course.author_id, course.level_id, course.series_id ]
    assert_equal "<div>Nouveau</div>", course.content.body.to_html
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("update.updated", name: "Génétique et évolution"))
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
  end

  test "an invalid update reopens the edit modal in 422; an unknown course is not found; without Turbo, the course page" do
    course = create_course(name: "Génétique", level: @tle, material: @svt)
    sign_in_as @member

    patch teams_course_path(course.slug), params: course_params(name: "")
    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal form#course-form #course_name_error", text: error(:name, :blank)
    assert_equal "Génétique", course.reload.name

    patch teams_course_path("inconnu"), params: course_params, as: :turbo_stream
    assert_response :not_found

    patch teams_course_path(course.slug), params: course_params(name: "Génétique bis")
    assert_redirected_to course_path("genetique")
    assert_equal tc("update.updated", name: "Génétique bis"), flash[:notice]
  end

  test "publishing a draft replaces its status panel, sets its publication date and writes the audit trail" do
    course = create_course(name: "Génétique", level: @tle, material: @svt, status: "draft")
    sign_in_as @member

    patch publish_teams_course_path(course.slug), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal "published", course.reload.status
    assert_not_nil course.published_at
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("transition.published", name: "Génétique"))
    assert_select "turbo-stream[action=replace][target=content_status_course_genetique]" do
      assert_select "#content_status_course_genetique", text: including(I18n.t("catalog.content_status.published"))
      assert_select "form[action='#{archive_teams_course_path('genetique')}']"
    end
    assert_equal [ [ "content.published", @member.id, course.id ] ], Orm::AuditEvent.pluck(:action, :actor_id, :subject_id)
  end

  test "a published course is archived, then published again; a second publication is refused in 422" do
    course = create_course(name: "Génétique", level: @tle, material: @svt)
    essential = create_essential(course:)
    assignment = create_assignment(assignable: course)
    sign_in_as @member

    patch archive_teams_course_path(course.slug), as: :turbo_stream
    assert_response :success
    assert_equal "archived", course.reload.status
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("transition.archived", name: "Génétique"))
    assert_select "#content_status_course_genetique form[action='#{publish_teams_course_path('genetique')}']"
    assert essential.reload.persisted?
    assert_equal "active", assignment.reload.status

    patch publish_teams_course_path(course.slug), as: :turbo_stream
    assert_response :success
    assert_equal "published", course.reload.status

    patch publish_teams_course_path(course.slug), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tc("transition.refused", name: "Génétique"))
    assert_select "turbo-stream[action=replace][target=content_status_course_genetique]"
    assert_equal %w[content.archived content.published], Orm::AuditEvent.order(:id).pluck(:action)
  end

  test "an unknown course cannot change status; without Turbo, a transition or its refusal leads to the course page" do
    course = create_course(name: "Génétique", level: @tle, material: @svt, status: "draft")
    sign_in_as @member

    patch publish_teams_course_path("inconnu"), as: :turbo_stream
    assert_response :not_found

    patch archive_teams_course_path(course.slug)
    assert_redirected_to course_path("genetique")
    assert_equal tc("transition.refused", name: "Génétique"), flash[:alert]

    patch publish_teams_course_path(course.slug)
    assert_redirected_to course_path("genetique")
    assert_equal tc("transition.published", name: "Génétique"), flash[:notice]
  end
end
