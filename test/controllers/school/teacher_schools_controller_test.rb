require "test_helper"

# ME-02, ME-04, ME-13 to ME-15 (ADR-0094 §4.4, UDR-0099 §3.1 to §3.3): « Mes établissements » lists the teacher's schools,
# adds one by DRENA then school (the session moves to it), and leaves one after a confirmation, never the last.
class School::TeacherSchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @drena = create_drena(name: "DRENA Abidjan 1")
    @a = create_school(drena: @drena, name: "Lycée moderne d'Abobo")
    @b = create_school(drena: @drena, name: "Collège Saint-Michel", sigle: "CSM")
    @c = create_school(drena: @drena, name: "Collège Notre-Dame")
    @teacher = create_teacher(school: @a)
  end

  def t(key, **) = I18n.t(key, **)
  def join(school) = post teacher_schools_path, params: { school_join: { drena_public_id: @drena.public_id, school_public_id: school.public_id } }
  def attached = Orm::TeacherSchool.where(teacher: @teacher).order(:created_at, :id).pluck(:school_id, :primary)

  test "one school: its card, « Principal » and « Vous êtes ici », no menu, and the card to add one" do
    sign_in_as @teacher
    get teacher_schools_path

    assert_response :success
    assert_select "h1", t("school.teacher_schools.index.title")
    assert_select "#teacher_school_#{@a.public_id}", text: /Lycée moderne d'Abobo.*DRENA Abidjan 1.*Principal.*Vous êtes ici/m
    assert_select "#teacher-school-menu-#{@a.public_id}", count: 0
    assert_select "form#go-school-#{@a.public_id}", count: 0
    assert_select "#add_school form#school-join-form[action='#{teacher_schools_path}']"
    assert_select "#add_school select[name='school_join[drena_public_id]'] option", text: "DRENA Abidjan 1"
  end

  test "ME-02: joining B from the page: secondary, the session moves to B, on to the classrooms of B" do
    sign_in_as @teacher
    join @b

    assert_redirected_to teacher_classrooms_path
    assert_equal t("school.teacher_schools.create.joined", school: "Collège Saint-Michel"), flash[:notice]
    assert_equal [ [ @a.id, true ], [ @b.id, false ] ], attached
    assert_equal [ @b.id ], Orm::Session.where(user_id: @teacher.id).pluck(:current_school_id)
    assert_equal({ "change" => "teacher_joined", "via" => "standard" }, Orm::AuditEvent.where(action: "school.changed").last.metadata)
    assert_not Orm::SchoolJoinRequest.exists?(teacher: @teacher), "ME-06 : aucune demande"
  end

  test "two schools: a menu to leave each, « Aller dans » the other one" do
    add_teacher_school(@teacher, @b)
    sign_in_as @teacher
    get teacher_schools_path

    assert_select "#teacher-school-menu-#{@a.public_id}"
    assert_select "#teacher_school_#{@b.public_id}", text: /Collège Saint-Michel \(CSM\)/
    assert_select "form#go-school-#{@b.public_id}[action='#{teacher_current_school_path}'] button[aria-label=?]",
                  t("school.teacher_schools.index.go_label", school: "Collège Saint-Michel")
    assert_select "dialog#leave-school-#{@b.public_id} form[action='#{teacher_school_path(@b.public_id)}']"
  end

  test "ME-04: three schools: the add card gives way to a sentence; a forged join is refused in the form" do
    add_teacher_school(@teacher, @b)
    add_teacher_school(@teacher, @c)
    sign_in_as @teacher
    get teacher_schools_path
    assert_select "#add_school", count: 0
    assert_select "#schools_limit", t("school.teacher_schools.index.limit", max: 3)

    join create_school(drena: @drena)

    assert_response :unprocessable_entity
    assert_select "#schools_limit"
    assert_equal 3, attached.size
  end

  test "already in the school, or a school that withdrew him: the reason, or the neutral error; nothing is written" do
    create_teacher_departure(teacher: @teacher, school: @c, detached_by: create_school_admin(school: @c))
    sign_in_as @teacher

    join @a
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Vous êtes déjà dans cet établissement/
    join @c
    assert_response :unprocessable_entity
    assert_match "Cet établissement ne peut pas être rejoint.", response.body
    assert_equal [ [ @a.id, true ] ], attached
  end

  test "ME-13: leaving B: back to the page with a toast, B is gone" do
    add_teacher_school(@teacher, @b)
    sign_in_as @teacher

    delete teacher_school_path(@b.public_id)

    assert_redirected_to teacher_schools_path
    assert_equal t("school.teacher_schools.destroy.left", school: "Collège Saint-Michel"), flash[:notice]
    assert_equal [ [ @a.id, true ] ], attached
  end

  test "ME-15: a forged DELETE of the last school is refused and changes nothing; a stranger's school is not found" do
    sign_in_as @teacher

    delete teacher_school_path(@a.public_id)
    assert_redirected_to teacher_schools_path
    assert_equal t("school.teacher_schools.destroy.last_school"), flash[:alert]
    delete teacher_school_path(@c.public_id)
    assert_response :not_found
    assert_equal [ [ @a.id, true ] ], attached
  end

  test "the DRENA chosen without JavaScript comes back in GET and lists its schools" do
    sign_in_as @teacher
    get teacher_schools_path, params: { school_join: { drena_public_id: @drena.public_id } }

    assert_select "#add_school select[name='school_join[school_public_id]'] option", text: "Collège Notre-Dame"
  end

  test "beyond 10 joins a minute: the error state, nothing is read" do
    sign_in_as @teacher
    10.times { join @a }
    join @b

    assert_response :too_many_requests
    assert_select "#add_school", text: /Trop de tentatives/
    assert_equal [ [ @a.id, true ] ], attached
  end

  test "students, directions and the team have no « Mes établissements »" do
    [ create_student, create_school_admin(school: @a) ].each do |user|
      sign_in_as user
      get teacher_schools_path
      assert_response :forbidden
      sign_out
    end
  end
end
