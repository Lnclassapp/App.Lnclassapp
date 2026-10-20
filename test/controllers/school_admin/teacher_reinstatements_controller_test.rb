require "test_helper"

# GD-19, GD-20 (ADR-0071 §4.3, UDR-0056 §3.4): « Réintégrer » attaches the teacher to the direction's school again,
# without any classroom, the row leaves the list without a reload; another school's teacher is 404, an inactive school 403.
class SchoolAdmin::TeacherReinstatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @other = create_school(name: "Lycée Classique d'Abidjan")
    @admin = create_school_admin(school: @school)
    @teacher = departed(first_name: "Awa", last_name: "Koné")
  end

  def t(key, **) = I18n.t("school_admin.teacher_reinstatements.create.#{key}", **)
  def shared(code) = I18n.t("school_admin.shared.errors.#{code}")

  def departed(school: @school, **attributes)
    create_teacher(school: nil, **attributes).tap do |teacher|
      create_teacher_departure(teacher:, school:, detached_by: @admin)
    end
  end

  def reinstate(teacher = @teacher, format: :turbo_stream)
    post school_admin_teacher_reinstatement_path(teacher.public_id), as: format
  end

  test "GD-19 : rattaché de nouveau, sans classe, devoirs archivés gardés ; la ligne part, toast, journal" do
    classroom = create_classroom(school: @school)
    archived = create_assignment(classroom:, by: @teacher, status: "archived")
    sign_in_as @admin
    departed(last_name: "Reste")

    reinstate

    assert_response :success
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id, :primary)
    assert_empty Orm::TeacherClassroom.where(teacher: @teacher)
    assert_equal "archived", archived.reload.status
    assert_not_nil Orm::TeacherSchoolDeparture.find_by(teacher: @teacher).reinstated_at
    assert_equal 1, Orm::AuditEvent.where(action: "teacher.reinstated", actor_id: @admin.id, subject_id: @teacher.id).count
    assert_select "turbo-stream[action=remove][target=departed_teacher_#{@teacher.public_id}]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(t('done', name: 'Awa Koné'))}/
    assert_select "turbo-stream[action=replace]", 0
  end

  # ADR-0103 §4.4 (EPM-15): the list survives the removal, whatever he writes elsewhere meanwhile, and comes back with him.
  test "removed, then writing another list elsewhere, then reinstated: his list is back, in its order" do
    pc, svt, maths = create_material(name: "Physique-Chimie"), create_material(name: "SVT"), create_material(name: "Mathématiques")
    teacher = create_teacher(school: @school, materials: [ pc, svt ])
    add_teacher_school(teacher, @other, materials: [ pc, svt ])
    list = ->(school) { Orm::TeacherSchoolMaterial.where(teacher:, school:).in_order.pluck(:material_id) }
    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :success
    sign_out

    sign_in_as teacher
    patch profile_materials_path, params: { profile_materials: { material_slugs: [ maths.slug ] } }
    assert_equal [ maths.id ], list.call(@other)
    sign_out

    sign_in_as @admin
    post school_admin_teacher_reinstatement_path(teacher.public_id), as: :turbo_stream

    assert_response :success
    assert_equal [ pc.id, svt.id ], list.call(@school)
    assert_equal [ maths.id ], list.call(@other), "l'autre établissement garde la sienne"
  end

  test "le dernier réintégré : la liste devient l'état vide" do
    sign_in_as @admin

    reinstate

    assert_select "turbo-stream[action=replace][target=departed_teachers] template div#departed_teachers",
                  text: /#{I18n.t('school_admin.departed_teachers.index.empty.title')}/
  end

  test "repli HTML : 303 vers « Enseignants retirés », avec l'avis" do
    sign_in_as @admin

    reinstate(format: :html)

    assert_redirected_to school_admin_departed_teachers_path
    assert_response :see_other
    assert_equal t("done", name: "Awa Koné"), flash[:notice]
    # Tournure neutre, quel que soit le genre du compte (porteur, 2026-10-01).
    assert_equal "Awa Koné est de nouveau dans l'établissement et doit redéclarer ses classes.", flash[:notice]
  end

  test "GD-20 : un enseignant retiré de B : 404, toast « Introuvable. », rien n'est écrit" do
    from_b = departed(school: @other)
    sign_in_as @admin

    reinstate(from_b)

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{shared(:not_found)}/
    assert_empty Orm::TeacherSchool.where(teacher: from_b)
    assert_nil Orm::TeacherSchoolDeparture.find_by(teacher: from_b).reinstated_at
  end

  # ME-21, ME-22 (ADR-0094 §4.4, UDR-0100 §3.3): joined elsewhere since, he is reinstated as a secondary school; at the
  # cap, a toast says why, nothing else of the other schools, and the row stays.
  test "ME-21 : rattaché ailleurs entre-temps : réintégré en secondaire, sans rien dire de l'autre établissement" do
    Orm::TeacherSchool.create!(teacher: @teacher, school: @other, primary: true)
    sign_in_as @admin

    reinstate

    assert_response :success
    assert_equal [ [ @other.id, true ], [ @school.id, false ] ], Orm::TeacherSchool.where(teacher: @teacher).order(:created_at, :id).pluck(:school_id, :primary)
    assert_not_includes response.body, "Lycée Classique d&#39;Abidjan"
  end

  test "ME-22 : au plafond : un toast dit pourquoi, la ligne reste, rien n'est écrit ; en HTML, retour à la liste" do
    [ @other, create_school, create_school ].each_with_index { |school, i| Orm::TeacherSchool.create!(teacher: @teacher, school:, primary: i.zero?) }
    sign_in_as @admin

    reinstate
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(t("schools_limit", name: "Awa"))}/
    assert_select "turbo-stream[action=remove]", 0
    reinstate(format: :html)
    assert_redirected_to school_admin_departed_teachers_path
    assert_equal t("schools_limit", name: "Awa"), flash[:alert]
    assert_equal 3, Orm::TeacherSchool.where(teacher: @teacher).count
    assert_nil Orm::TeacherSchoolDeparture.find_by(teacher: @teacher).reinstated_at
  end

  test "déjà réintégré, inconnu : 404 ; en HTML, la page 404" do
    sign_in_as @admin
    reinstate
    assert_response :success

    reinstate
    assert_response :not_found

    reinstate(format: :html)
    assert_response :not_found
    assert_select "main", text: /#{Regexp.escape(I18n.t('errors.not_found.title'))}/

    post school_admin_teacher_reinstatement_path("usr-inconnu"), as: :turbo_stream
    assert_response :not_found
  end

  test "un établissement inactif : 403, toast, rien n'est écrit" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    reinstate

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(shared(:forbidden))}/
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)

    reinstate(format: :html)
    assert_response :forbidden
  end

  test "l'équipe, un enseignant, une direction sans établissement : 403" do
    [ create_team_member, create_teacher(school: @school), create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      reinstate
      assert_response :forbidden, user.role
      sign_out
    end
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)
  end
end
