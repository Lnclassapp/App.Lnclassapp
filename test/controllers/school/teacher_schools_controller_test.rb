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

  test "one school: its line with « En cours », no « Retirer » button, and the card to add one" do
    sign_in_as @teacher
    get teacher_schools_path

    assert_response :success
    assert_select "h1", t("school.teacher_schools.index.title")
    assert_select "main a[href='#{teacher_menu_path}']", text: /Mon compte/
    assert_select "p", text: "1 sur 3."
    assert_select "#teacher_school_#{@a.public_id}", text: /Lycée moderne d'Abobo.*En cours/m
    assert_select "#teacher_school_#{@a.public_id}", text: /DRENA/, count: 0
    assert_select "#teacher_school_#{@a.public_id} dialog", 0, "CA-H5 : le seul établissement n'a pas de bouton"
    assert_select "#teacher_school_#{@a.public_id} button", 0
    assert_select "#add_school form#school-join-form[action='#{teacher_schools_path}']"
    assert_select "#add_school select[name='school_join[drena_public_id]'] option", text: "DRENA Abidjan 1"
  end

  test "ME-02: joining B from the page: secondary, the session moves to B, on to the classrooms of B" do
    @teacher.teacher_profile.update!(joined_via: "direction")
    sign_in_as @teacher
    join @b

    assert_redirected_to teacher_classrooms_path
    assert_equal t("school.teacher_schools.create.joined", school: "Collège Saint-Michel"), flash[:notice]
    assert_equal [ [ @a.id, true ], [ @b.id, false ] ], attached
    assert_equal [ @b.id ], Orm::Session.where(user_id: @teacher.id).pluck(:current_school_id)
    assert_equal({ "change" => "teacher_joined", "via" => "standard" }, Orm::AuditEvent.where(action: "school.changed").last.metadata)
    assert_not Orm::SchoolJoinRequest.exists?(teacher: @teacher), "ME-06 : aucune demande"
    assert_equal "direction", @teacher.teacher_profile.reload.joined_via, "ME-06 : la voie d'arrivée ne change pas"
  end

  test "two schools: « 2 sur 3 », a « Retirer » with its confirmation on each line, only the current one « En cours »" do
    add_teacher_school(@teacher, @b)
    sign_in_as @teacher
    get teacher_schools_path

    assert_select "p", text: "2 sur 3."
    assert_select "#teacher_school_#{@a.public_id} .ui-badge", text: "En cours"
    assert_select "#teacher_school_#{@b.public_id} .ui-badge", 0
    assert_select "#teacher_school_#{@b.public_id}", text: /CSM.*Collège Saint-Michel/m
    assert_select "#teacher_school_#{@b.public_id}", text: /DRENA/, count: 0
    assert_select "#teacher_school_#{@b.public_id} button[aria-controls='leave-school-#{@b.public_id}']", text: /Retirer\s+Collège Saint-Michel/
    assert_select "#teacher_school_#{@a.public_id} button[aria-controls='leave-school-#{@a.public_id}']", text: /Retirer/
    assert_select "dialog#leave-school-#{@b.public_id} form[action='#{teacher_school_path(@b.public_id)}']"
    assert_select "dialog#leave-school-#{@b.public_id} h2", "Retirer Collège Saint-Michel ?"
    assert_select "main p", text: "Vos classes et devoirs en cours dans l'établissement retiré sont archivés."
    assert_select "#add_school"
  end

  # CA-H7 (lot P0) : dans le frame du panneau « Mon compte » (dès lg), le formulaire d'ajout quitte le frame : le rattachement mène
  # à « Mes classes », une page entière ; l'alerte d'un retrait refusé se lit dans le frame.
  test "CA-H7: in the frame of the account panel, the screen is the frame alone, its add form leaves it, and the alert is read there" do
    add_teacher_school(@teacher, @b)
    sign_in_as @teacher
    frame = { "Turbo-Frame" => NavigationHelper::ACCOUNT_PANEL_FRAME }

    delete teacher_school_path(@b.public_id)
    delete teacher_school_path(@a.public_id)
    get teacher_schools_path, headers: frame

    assert_response :success
    assert_no_match(/<aside|<header|<main/, response.body)
    assert_select "turbo-frame##{NavigationHelper::ACCOUNT_PANEL_FRAME}", 1 do
      assert_select "p[role=alert]", "Vous ne pouvez pas quitter votre seul établissement."
      assert_select "a[href='#{teacher_menu_path}']", text: /Mon compte/
      assert_select "turbo-frame#teacher_school_join[target=_top] #add_school form#school-join-form"
    end
    get teacher_schools_path
    assert_select "main turbo-frame#teacher_school_join, main turbo-frame##{NavigationHelper::ACCOUNT_PANEL_FRAME}", 0
  end

  test "ME-04: three schools: « 3 sur 3. Retirez-en un pour en ajouter un autre. », no add card; a forged join is refused" do
    add_teacher_school(@teacher, @b)
    add_teacher_school(@teacher, @c)
    sign_in_as @teacher
    get teacher_schools_path
    assert_select "#add_school", count: 0
    assert_select "#schools_limit", "3 sur 3. Retirez-en un pour en ajouter un autre."

    join create_school(drena: @drena)

    assert_response :unprocessable_entity
    assert_select "#schools_limit"
    assert_select "#schools_limit_error", "Vous avez atteint 3 établissements."
    assert_equal 3, attached.size
  end

  test "CA-H4: at three schools, leaving one archives its classes and active assignments, and the count falls to 2 sur 3" do
    add_teacher_school(@teacher, @b)
    add_teacher_school(@teacher, @c)
    classroom = create_classroom(school: @c)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    assignment = create_assignment(classroom:, by: @teacher)
    kept = create_assignment(classroom: create_classroom(school: @a), by: @teacher)
    sign_in_as @teacher

    delete teacher_school_path(@c.public_id)

    assert_redirected_to teacher_schools_path
    assert_equal "archived", assignment.reload.status
    assert_equal "active", kept.reload.status
    assert_not Orm::TeacherClassroom.exists?(teacher: @teacher, classroom:)
    follow_redirect!
    assert_select "p", text: "2 sur 3."
    assert_select "#teacher_school_#{@c.public_id}", 0
    assert_select "#add_school"
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

    join @b
    assert_redirected_to teacher_classrooms_path, "aucun départ n'est noté : il peut revenir"
    assert_equal [ [ @a.id, true ], [ @b.id, false ] ], attached
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

  test "students, directions and the team have no « Mes établissements », and can neither join nor leave" do
    [ create_student, create_school_admin(school: @a), create_team_member ].each do |user|
      sign_in_as user
      get teacher_schools_path
      assert_response :forbidden, user.role
      join @b
      assert_response :forbidden, user.role
      delete teacher_school_path(@a.public_id)
      assert_response :forbidden, user.role
      sign_out
    end
    assert_equal [ [ @a.id, true ] ], attached
  end
end
