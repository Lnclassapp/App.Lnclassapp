require "test_helper"

# CL-01, CL-04, UDR-0006, UDR-0031: the team adds a classroom to a school in a modal opened from the school's page — the
# join code is drawn on creation and shown in capitals, errors come back in 422 in the modal, HTML fallback.
class Teams::SchoolClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    referential = seed_referential
    @levels = referential[:levels]
    @series = referential[:series]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
  end

  # PRD §4: messages are compared through their locale key, never written out in the test.
  def tc(key, **) = I18n.t("teams.school_classrooms.#{key}", **)
  def error(field, kind) = I18n.t("activemodel.errors.models.dtos/classroom/classroom_input.attributes.#{field}.#{kind}")
  def including(text) = /#{Regexp.escape(text)}/

  def classroom_params(level_slug: "tle", series_slug: "d", name: "Tle D 7", max_students: "60")
    { classroom: { level_slug:, series_slug:, name:, max_students: } }
  end

  def create_path(school = @school) = school_classrooms_path(school.public_id)

  test "a student, a teacher or a school head receives 403, not 500, and nothing is written" do
    [ create_student, create_teacher(school: @school), create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      get new_school_classroom_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }
      assert_response :forbidden
      post create_path, params: classroom_params, as: :turbo_stream
      assert_response :forbidden
      assert_select "turbo-stream[action=append][target=toasts]", text: including(I18n.t("errors.codes.forbidden"))
      sign_out
    end

    assert_equal 0, Orm::Classroom.count
  end

  test "an unknown school gives 404" do
    sign_in_as @member

    get new_school_classroom_path("inconnu"), headers: { "Turbo-Frame" => "modal" }
    assert_response :not_found
    post school_classrooms_path("inconnu"), params: classroom_params, as: :turbo_stream
    assert_response :not_found
  end

  test "the new form opens in the modal frame, with the series filed under their level and a default cap of 80" do
    sign_in_as @member

    get new_school_classroom_path(@school.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal [data-modal-open-value=true] dialog form#classroom-form[action='#{create_path}'][method=post]"
    assert_select "turbo-frame#modal", text: including(@school.name)
    assert_select "select[name='classroom[level_slug]'] option:not([value=''])", 7
    assert_select "select[name='classroom[series_slug]'] > option[value='']", text: tc("form.no_series")
    assert_select "select[name='classroom[series_slug]'] optgroup[label=Tle] option", 4
    assert_select "select[name='classroom[series_slug]'] optgroup[label=Tle] option[value=d]", text: "D"
    assert_select "select[name='classroom[series_slug]'] optgroup", 3
    assert_select "input[name='classroom[name]'][maxlength='15'][required]"
    assert_select "input[type=number][name='classroom[max_students]'][value='80'][min='1'][max='150']"
    assert_select "input[name='classroom[join_code]']", 0
    assert_select "button[type=submit][form=classroom-form]", text: tc("new.submit")
  end

  test "a lower secondary school only offers first-cycle levels, hence no series" do
    college = create_school(name: "Collège Moderne de Cocody", cycle: "first")
    sign_in_as @member

    get new_school_classroom_path(college.public_id)

    assert_response :success
    assert_select "select[name='classroom[level_slug]'] option:not([value=''])", 4
    assert_select "select[name='classroom[level_slug]'] option[value=tle]", 0
    assert_select "select[name='classroom[series_slug]'] optgroup", 0
  end

  test "CL-01, CL-04: a created classroom belongs to the current school year, its code drawn in lower case and toasted in capitals" do
    sign_in_as @member

    post create_path, params: classroom_params, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    classroom = Orm::Classroom.sole
    assert_equal [ @school.id, @levels["tle"].id, @series["d"].id, "Tle D 7", 60, "active", current_school_year ],
                 [ classroom.school_id, classroom.level_id, classroom.series_id, classroom.name, classroom.max_students,
                   classroom.status, classroom.school_year ]
    assert_match Entities::Classroom::JoinCode::FORMAT, classroom.join_code
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("create.created", code: classroom.join_code.upcase))
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]:not([request-id])"
  end

  test "CL-01: the join code column is exactly as long as a generated code" do
    assert_equal Entities::Classroom::JoinCode::LENGTH, Orm::Classroom.columns_hash.fetch("join_code").limit
  end

  test "a name taken in the school and year reopens the modal in 422 with the error and the typed values" do
    create_classroom(school: @school, level: @levels["tle"], series: @series["d"], name: "Tle D 7")
    sign_in_as @member

    post create_path, params: classroom_params(max_students: "45")

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [data-modal-open-value=true] dialog #classroom_name_error", text: error(:name, :taken)
    assert_select "select[name='classroom[level_slug]'] option[selected][value=tle]"
    assert_select "select[name='classroom[series_slug]'] option[selected][value=d]"
    assert_select "input[name='classroom[max_students]'][value='45']"
    assert_equal 1, Orm::Classroom.count
  end

  test "the same name in another school, or last year, is free" do
    create_classroom(school: create_school, level: @levels["tle"], name: "Tle D 7")
    create_classroom(school: @school, level: @levels["tle"], name: "Tle D 7", school_year: "2020-2021")
    sign_in_as @member

    post create_path, params: classroom_params, as: :turbo_stream

    assert_response :success
    assert_equal 3, Orm::Classroom.where(name: "Tle D 7").count
  end

  test "CL-01: series D for 6ème, a blank name or a cap above 150 reopen the modal in 422" do
    sign_in_as @member

    post create_path, params: classroom_params(level_slug: "6eme")
    assert_response :unprocessable_entity
    assert_select "#classroom_series_slug_error", text: error(:series_slug, :not_allowed)

    post create_path, params: classroom_params(name: " ", max_students: "151")
    assert_response :unprocessable_entity
    assert_select "#classroom_name_error", text: error(:name, :blank)
    assert_select "#classroom_max_students_error", text: error(:max_students, :in)

    assert_equal 0, Orm::Classroom.count
  end

  test "a deactivated school takes no new classroom: 422 with the reason in the modal" do
    closed = create_school(status: "inactive")
    sign_in_as @member

    post create_path(closed), params: classroom_params

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [role=alert]", text: error(:base, :school_inactive)
    assert_equal 0, Orm::Classroom.count
  end

  test "a draft school takes no classroom until it is activated: 422 with the reason in the modal" do
    draft = create_school(status: "draft")
    sign_in_as @member

    post create_path(draft), params: classroom_params

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal [role=alert]", text: error(:base, :school_draft)
    assert_equal 0, Orm::Classroom.count
  end

  test "without Turbo, the new form is a modal open on the shell, and a created classroom leads to its page" do
    sign_in_as @member

    get new_school_classroom_path(@school.public_id)
    assert_response :success
    assert_select "nav"
    assert_select "[data-modal-open-value=true] dialog form#classroom-form"

    post create_path, params: classroom_params(level_slug: "6eme", series_slug: "", name: "6ème 5")

    classroom = Orm::Classroom.sole
    assert_redirected_to classroom_path(classroom.public_id)
    assert_equal tc("create.created", code: classroom.join_code.upcase), flash[:notice]
    assert_nil classroom.series_id
  end
end
