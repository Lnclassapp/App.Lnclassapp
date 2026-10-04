require "test_helper"

# ID-12 to ID-16 (ADR-0077 §4.3, UDR-0070 §3.4): a direction removes another direction of its active school, there for at
# least 7 days, never itself. The account is archived by it, every session of the target is closed, the removal is audited.
class SchoolAdmin::StaffMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 10.days.ago)
    @aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 2.days.ago)
  end

  def ts(key, **) = I18n.t("shared.school_staff.#{key}", **)
  def staff_of(user) = Orm::SchoolStaff.find_by!(user_id: user.id)

  def assert_nothing_written
    assert_nil Orm::SchoolStaff.where.not(archived_at: nil).first
    assert_not Orm::AuditEvent.exists?(action: "school_staff.archived")
  end

  test "ID-12 : Kofi retire Aya : archivée par Kofi, sessions fermées, ligne retirée, places recomptées, toast, journal" do
    aya_session = open_session.tap { it.post session_path, params: { session: { contact: @aya.contact, pin: "2468" } } }
    assert_operator Orm::Session.where(user_id: @aya.id).count, :>, 0

    sign_in_as @kofi
    delete school_admin_staff_member_path(@aya.public_id), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=school_staff_#{@aya.public_id}]"
    assert_select "turbo-stream[action=replace][target=school_staff_places] template p#school_staff_places",
                  text: ts("subtitle", used: 1, cap: 3)
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('done', name: 'Aya Koné'))}/
    staff = staff_of(@aya)
    assert_equal @kofi.id, staff.archived_by_id
    assert_not_nil staff.archived_at
    assert_nil staff_of(@kofi).archived_at
    assert_equal 0, Orm::Session.where(user_id: @aya.id).count
    assert_operator Orm::Session.where(user_id: @kofi.id).count, :>, 0
    event = Orm::AuditEvent.find_by!(action: "school_staff.archived")
    assert_equal [ @kofi.id, "User", @aya.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "school_id" => @school.id, "joined_via" => "code" }, event.metadata)

    aya_session.get school_admin_classrooms_path
    aya_session.assert_redirected_to new_session_path
  end

  test "repli HTML : 303 vers Établissement, avec la notice" do
    sign_in_as @kofi
    delete school_admin_staff_member_path(@aya.public_id)

    assert_redirected_to school_admin_school_path
    assert_equal 303, response.status
    assert_equal ts("done", name: "Aya Koné"), flash[:notice]
  end

  test "ID-13 : un DELETE forgé d'Aya (2 jours) sur Kofi répond 403, toast, rien n'est écrit" do
    sign_in_as @aya
    delete school_admin_staff_member_path(@kofi.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('forbidden'))}/
    assert_nothing_written

    delete school_admin_staff_member_path(@kofi.public_id)
    assert_response :forbidden
  end

  test "ID-14 : Kofi sur sa propre ligne : 403, rien n'est écrit" do
    sign_in_as @kofi
    delete school_admin_staff_member_path(@kofi.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_nothing_written
  end

  test "ID-15 : Kofi sur une direction de B : 404, toast « Introuvable. », rien n'est écrit" do
    zadi = create_school_admin(school: create_school, joined_at: 30.days.ago)

    sign_in_as @kofi
    delete school_admin_staff_member_path(zadi.public_id), as: :turbo_stream

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('not_found'))}/
    assert_nothing_written

    delete school_admin_staff_member_path(zadi.public_id)
    assert_response :not_found
  end

  test "ID-16 : établissement désactivé : un DELETE forgé répond 403" do
    @school.update!(status: "inactive")

    sign_in_as @kofi
    delete school_admin_staff_member_path(@aya.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_nothing_written
  end

  test "déjà retirée (deux onglets) ou compte inconnu : 404" do
    sign_in_as @kofi
    delete school_admin_staff_member_path(@aya.public_id), as: :turbo_stream
    assert_response :success

    delete school_admin_staff_member_path(@aya.public_id), as: :turbo_stream
    assert_response :not_found
    delete school_admin_staff_member_path("inconnu"), as: :turbo_stream
    assert_response :not_found
    assert_equal 1, Orm::AuditEvent.where(action: "school_staff.archived").count
  end

  test "élève, enseignant et équipe reçoivent 403 ; le visiteur va à « Se connecter »" do
    delete school_admin_staff_member_path(@aya.public_id)
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member(team_role: "field") ].each do |user|
      sign_in_as user
      delete school_admin_staff_member_path(@aya.public_id), as: :turbo_stream
      assert_response :forbidden, user.role
      sign_out
    end
    assert_nothing_written
  end
end
