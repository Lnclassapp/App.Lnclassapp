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
    # ADR-0060: no direct upload address, the Active Storage routes are not drawn.
    assert_select "trix-editor#course_content[data-direct-upload-url=''][data-blob-url-template='']"
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

  # ADR-0075, RE-27: a Tle D course whose exercise is assigned to a Tle D 1 keeps a level that covers this classroom.
  def assigned_course
    course = create_course(name: "Génétique", level: @tle, series: @d, material: @svt)
    assignment = create_assignment(classroom: create_classroom(name: "Tle D 1", level: @tle, series: @d),
                                   assignable: create_exercise(essential: create_essential(course:)))
    [ course, assignment ]
  end

  test "RE-27: moving an assigned course out of its classroom's level or series is refused in 422, under « Niveau »" do
    create_level(name: "3ème", position: 4, cycle: "first")
    link_level_series(level: @tle, series: @c)
    course, = assigned_course
    sign_in_as @member

    [ { level_slug: "3eme", series_slug: "" }, { series_slug: "c" } ].each do |taxonomy|
      patch teams_course_path(course.slug), params: course_params(name: "Génétique", **taxonomy)

      assert_response :unprocessable_entity
      assert_select "turbo-frame#modal form#course-form" do
        assert_select "label[for=course_level_slug]", text: including(I18n.t("activemodel.attributes.dtos/catalog/course_input.level_slug"))
        assert_select "select#course_level_slug[aria-invalid=true][aria-describedby~=course_level_slug_error]"
        assert_select "#course_level_slug_error", text: error(:level_slug, :assigned_elsewhere)
        assert_select "select[name='course[level_slug]'] option[selected][value=?]", taxonomy.fetch(:level_slug, "tle")
      end
    end
    assert_equal [ "Génétique", @tle.id, @d.id ], course.reload.attributes.values_at("name", "level_id", "series_id")
  end

  test "RE-27: an assigned course widens to « Tle » without series and is renamed; once unassigned, its level changes" do
    third = create_level(name: "3ème", position: 4, cycle: "first")
    course, assignment = assigned_course
    sign_in_as @member

    patch teams_course_path(course.slug), params: course_params(name: "Génétique", series_slug: ""), as: :turbo_stream
    assert_response :success
    assert_equal [ @tle.id, nil ], course.reload.attributes.values_at("level_id", "series_id")

    patch teams_course_path(course.slug), params: course_params(name: "Génétique humaine", series_slug: ""), as: :turbo_stream
    assert_response :success
    assert_equal "Génétique humaine", course.reload.name

    assignment.update!(status: "archived", archived_at: Time.current)
    patch teams_course_path(course.slug), params: course_params(name: "Génétique humaine", level_slug: "3eme", series_slug: ""),
                                          as: :turbo_stream
    assert_response :success
    assert_equal [ third.id, nil ], course.reload.attributes.values_at("level_id", "series_id")
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
    end
    # Les transitions sont des entrées du menu ⋮, remplacées avec le statut.
    assert_select "turbo-stream[action=replace][target=content_transitions_course_genetique]" do
      assert_select "a[role=menuitem][data-turbo-method=patch][href='#{archive_teams_course_path('genetique')}']"
      assert_select "a[href='#{publish_teams_course_path('genetique')}']", 0
    end
    assert_equal [ [ "content.published", @member.id, course.id ] ], Orm::AuditEvent.pluck(:action, :actor_id, :subject_id)
  end

  test "a published course is archived, then published again; a second publication is refused in 422" do
    course = create_course(name: "Génétique", level: @tle, material: @svt)
    essential = create_essential(course:)
    assignment = create_assignment(assignable: create_exercise(essential:))
    sign_in_as @member

    patch archive_teams_course_path(course.slug), as: :turbo_stream
    assert_response :success
    assert_equal "archived", course.reload.status
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("transition.archived", name: "Génétique"))
    assert_select "#content_transitions_course_genetique a[data-turbo-method=patch][href='#{publish_teams_course_path('genetique')}']"
    assert essential.reload.persisted?
    assert_equal "active", assignment.reload.status

    patch publish_teams_course_path(course.slug), as: :turbo_stream
    assert_response :success
    assert_equal "published", course.reload.status

    patch publish_teams_course_path(course.slug), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: including(tc("transition.refused", name: "Génétique"))
    assert_select "turbo-stream[action=replace][target=content_status_course_genetique]"
    assert_select "turbo-stream[action=replace][target=content_transitions_course_genetique]"
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

  # ADR-0035, amendement du 2026-10-01 : « Tout publier » depuis le menu ⋮ du cours.
  def cascade(key, **) = I18n.t("teams.publish_cascade.#{key}", **)

  test "« Tout publier » publishes the course, its draft sheets and their complete draft exercises; the rest stays as it is" do
    course = create_course(name: "Génétique", level: @tle, material: @svt, status: "draft")
    meiose = create_essential(course:, name: "La méiose", status: "draft")
    archived = create_essential(course:, status: "archived")
    complete = create_exercise(essential: meiose, status: "draft")
    incomplete = create_exercise(essential: meiose, status: "draft", questions: 0)
    waiting = create_exercise(essential: archived, status: "draft")
    sign_in_as @member

    patch publish_all_teams_course_path(course.slug), as: :turbo_stream

    assert_response :success
    assert_equal %w[published published published draft archived draft],
                 [ course, meiose, complete, incomplete, archived, waiting ].map { it.reload.status }
    done = cascade("done.course", name: "Génétique", essentials: cascade("essentials", count: 1), exercises: cascade("exercises", count: 1))
    assert_select "turbo-stream[action=append][target=toasts]", text: including(done)
    assert_select "turbo-stream[action=append][target=toasts]", text: including(cascade("skipped", count: 1))
    assert_select "turbo-stream[action=refresh]", 1
    assert_equal [ [ "Course", course.id ], [ "Essential", meiose.id ], [ "Exercise", complete.id ] ],
                 Orm::AuditEvent.where(action: "content.published").order(:id).pluck(:subject_type, :subject_id)
  end

  test "« Tout publier » on a course where all is published says so, and writes nothing" do
    course = create_course(name: "Génétique", level: @tle, material: @svt)
    create_exercise(essential: create_essential(course:))
    sign_in_as @member

    patch publish_all_teams_course_path(course.slug), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(cascade("done.course", name: "Génétique", essentials: cascade("essentials", count: 0),
                                                         exercises: cascade("exercises", count: 0)))
    assert_select "turbo-stream[action=append][target=toasts]", 1
    assert_not Orm::AuditEvent.exists?
  end

  test "« Tout publier »: a teacher is refused, an unknown course is not found, and without Turbo it leads back with the summary" do
    course = create_course(name: "Génétique", level: @tle, material: @svt, status: "draft")
    sign_in_as create_teacher

    patch publish_all_teams_course_path(course.slug), as: :turbo_stream
    assert_response :forbidden
    assert_equal "draft", course.reload.status
    sign_out

    sign_in_as @member
    patch publish_all_teams_course_path("inconnu"), as: :turbo_stream
    assert_response :not_found

    patch publish_all_teams_course_path(course.slug), headers: { "HTTP_REFERER" => course_path(course.slug) }
    assert_redirected_to course_path(course.slug)
    assert_equal cascade("done.course", name: "Génétique", essentials: cascade("essentials", count: 0),
                                        exercises: cascade("exercises", count: 0)), flash[:notice]
    assert_equal "published", course.reload.status
  end
end
