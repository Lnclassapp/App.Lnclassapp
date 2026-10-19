require "test_helper"

# ME-01, ME-03, ME-05, ME-16 (ADR-0094 §4.4, UDR-0099 §3.4): a signed-in teacher who opens a link /i/<jeton> is asked
# « Rejoindre <établissement> ? » and joins with one click; already in it, at the cap, or an invalid link: the matching
# card, and nothing is written. The school that withdrew him shows the same card; the POST answers the neutral error.
class School::TeacherSchoolJoinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @a = create_school(name: "Lycée moderne d'Abobo")
    @b = create_school(name: "Collège Saint-Michel", drena: create_drena(name: "DRENA Abidjan 4"))
    @teacher = create_teacher(school: @a, joined_via: "standard")
    sign_in_as @teacher
  end

  def t(key, **) = I18n.t("school.teacher_school_joins.new.#{key}", **)
  def attached = Orm::TeacherSchool.where(teacher: @teacher).order(:created_at, :id).pluck(:school_id, :primary)

  test "ME-01: the direction's link opened signed in asks to join B; one click attaches B, the session moves to B" do
    get teacher_invite_link_path(@b.direction_invite_token)
    assert_redirected_to teacher_school_join_path(@b.direction_invite_token)
    follow_redirect!

    assert_select "#join_school h1", t("confirm.title", school: "Collège Saint-Michel")
    assert_select "#join_school", text: /DRENA Abidjan 4 · invité par la direction/
    assert_empty attached.select { it.first == @b.id }, "rien n'est écrit à l'ouverture"

    post teacher_school_join_path(@b.direction_invite_token)

    assert_redirected_to teacher_classrooms_path
    assert_equal [ [ @a.id, true ], [ @b.id, false ] ], attached
    assert_equal [ @b.id ], Orm::Session.where(user_id: @teacher.id).pluck(:current_school_id)
    assert_equal({ "change" => "teacher_joined", "via" => "direction" }, Orm::AuditEvent.where(action: "school.changed").last.metadata)
    assert_equal "standard", @teacher.teacher_profile.reload.joined_via, "ME-06 : la voie d'arrivée ne change pas"
    assert_not Orm::SchoolJoinRequest.exists?(teacher: @teacher)
  end

  test "a colleague's link names the colleague" do
    colleague = create_teacher(school: @b, first_name: "Awa", last_name: "Traoré")
    get teacher_school_join_path(Orm::TeacherSchool.find_by!(teacher: colleague).invite_token)

    assert_select "#join_school", text: /invité par Awa Traoré/
  end

  # ADR-0094 §11: the colleague's sponsor link has no school; it is for signing up, not for joining.
  test "a colleague's sponsor link says it signs up a new colleague; a forged POST writes nothing" do
    token = create_teacher(school: @b).teacher_profile.referral_token
    get teacher_school_join_path(token)

    assert_select "h1", t("sponsor.title")
    assert_select "a[href='#{teacher_schools_path}']", t("schools")
    post teacher_school_join_path(token)
    assert_response :unprocessable_entity
    assert_equal 1, attached.size
  end

  test "ME-05: already in B: « Vous êtes déjà dans » and a button to go there; a forged POST writes nothing" do
    add_teacher_school(@teacher, @b)
    get teacher_school_join_path(@b.team_invite_token)

    assert_select "h1", t("already.title", school: "Collège Saint-Michel")
    assert_select "form#go-school-form[action='#{teacher_current_school_path}'] input[name=school_public_id][value='#{@b.public_id}']"
    post teacher_school_join_path(@b.team_invite_token)
    assert_response :unprocessable_entity
    assert_select "h1", t("already.title", school: "Collège Saint-Michel")
    assert_equal 2, attached.size
  end

  test "ME-04: at the cap: « Vous avez déjà 3 établissements », and a forged POST writes nothing" do
    2.times { add_teacher_school(@teacher, create_school) }
    get teacher_school_join_path(@b.direction_invite_token)

    assert_select "h1", t("limit.title", max: 3)
    post teacher_school_join_path(@b.direction_invite_token)
    assert_response :unprocessable_entity
    assert_select "h1", t("limit.title", max: 3)
    assert_equal 3, attached.size
  end

  test "ME-16: an unknown token, an inactive school, an anonymized colleague: « Ce lien n'est plus valable »" do
    inactive = create_school(status: "inactive")
    gone = create_teacher(school: @b, anonymized_at: Time.current)

    [ "0123456789ab", inactive.direction_invite_token, Orm::TeacherSchool.find_by!(teacher: gone).invite_token ].each do |token|
      get teacher_school_join_path(token)
      assert_response :success
      assert_select "h1", t("invalid.title")
      assert_select "a[href='#{teacher_schools_path}']", t("schools")
    end
    assert_equal 1, attached.size
  end

  test "ME-03: the school that withdrew him shows the same card; the POST answers « Ce lien n'est plus valable »" do
    create_teacher_departure(teacher: @teacher, school: @b, detached_by: create_school_admin(school: @b))
    get teacher_school_join_path(@b.direction_invite_token)
    assert_select "#join_school h1", t("confirm.title", school: "Collège Saint-Michel")

    post teacher_school_join_path(@b.direction_invite_token)

    assert_response :unprocessable_entity
    assert_select "h1", t("invalid.title")
    assert_equal [ [ @a.id, true ] ], attached
  end

  test "a student, a direction or the team opening the link signed in goes to their home, as before; joining is refused" do
    sign_out
    [ create_student, create_school_admin(school: @a), create_team_member ].each do |user|
      sign_in_as user
      get teacher_invite_link_path(@b.direction_invite_token)
      assert_response :redirect, user.role
      assert_not_equal teacher_school_join_path(@b.direction_invite_token), URI(response.location).path
      get teacher_school_join_path(@b.direction_invite_token)
      assert_response :forbidden, user.role
      post teacher_school_join_path(@b.direction_invite_token)
      assert_response :forbidden, user.role
      sign_out
    end
    assert_not Orm::TeacherSchool.exists?(school: @b)
  end

  test "beyond 10 requests a minute: 429, nothing is read nor written" do
    11.times { get teacher_school_join_path(@b.direction_invite_token) }
    assert_response :too_many_requests

    post teacher_school_join_path(@b.direction_invite_token)
    assert_response :too_many_requests
    assert_equal [ [ @a.id, true ] ], attached
  end
end
