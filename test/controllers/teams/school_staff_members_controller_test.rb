require "test_helper"

# ID-18 (ADR-0077 §4.3, UDR-0070 §3.4, §3.5): a field or admin team member removes a direction from its school's page. The
# account is archived by the member, its sessions are closed, the removal is audited, and the streams update the
# « Direction » block and « Directions retirées ». A content member is refused; a direction of another school is not found.
class Teams::SchoolStaffMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", gender: "male", joined_via: "code", joined_at: 2.days.ago)
    @aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "invitation", joined_at: 20.days.ago)
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Bamba")
  end

  def ts(key, **) = I18n.t("shared.school_staff.#{key}", **)
  def staff_of(user) = Orm::SchoolStaff.find_by!(user_id: user.id)
  def remove(user, school: @school, **) = delete(school_staff_member_path(school.public_id, user.public_id), **)

  def assert_nothing_written
    assert_nil Orm::SchoolStaff.where.not(archived_at: nil).first
    assert_not Orm::AuditEvent.exists?(action: "school_staff.archived")
  end

  test "ID-18 : field retire Kofi : archivé par lui, sessions fermées, ligne retirée, places recomptées, retirés à jour, journal" do
    kofi_session = open_session.tap { it.post session_path, params: { session: { contact: @kofi.contact, pin: "2468" } } }

    sign_in_as @field
    freeze_time do
      remove @kofi, as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('done.male', name: 'Kofi Yao'))}/
      assert_select "turbo-stream[action=remove][target=school_staff_#{@kofi.public_id}]"
      assert_select "turbo-stream[action=replace][target=school_staff_places] template p#school_staff_places",
                    text: ts("subtitle", used: 0, cap: 3)
      assert_select "turbo-stream[action=replace][target=school_archived_staff] template #school_archived_staff" do
        assert_select "li#school_archived_staff_#{@kofi.public_id}", text: /Kofi Yao/ do
          assert_select "*", text: /Retiré le .+ par Awa Bamba/
          due = 30.days.from_now.to_date
          due_text = due.day == 1 ? "1er #{I18n.l(due, format: '%B %Y')}" : I18n.l(due, format: :long)
          assert_select "*", text: /Supprimé le #{Regexp.escape(due_text)}/
          assert_select "button[type=submit]", text: I18n.t("teams.schools.archived_staff.restore")
        end
      end
    end
    staff = staff_of(@kofi)
    assert_equal @field.id, staff.archived_by_id
    assert_not_nil staff.archived_at
    assert_equal 0, Orm::Session.where(user_id: @kofi.id).count
    event = Orm::AuditEvent.find_by!(action: "school_staff.archived")
    assert_equal [ @field.id, @kofi.id ], [ event.actor_id, event.subject_id ]
    assert_equal({ "school_id" => @school.id, "joined_via" => "code" }, event.metadata)

    kofi_session.get school_admin_classrooms_path
    kofi_session.assert_redirected_to new_session_path
  end

  test "repli HTML : 303 vers la fiche, avec la notice" do
    sign_in_as @field
    remove @aya

    assert_redirected_to school_path(@school.public_id)
    assert_equal 303, response.status
    assert_equal ts("done.female", name: "Aya Koné"), flash[:notice]
  end

  test "un membre content reçoit 403, toast, rien n'est écrit" do
    sign_in_as create_team_member(team_role: "content")
    remove @kofi, as: :turbo_stream

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('forbidden'))}/
    remove @kofi
    assert_response :forbidden
    assert_nothing_written
  end

  test "une direction d'un autre établissement, un établissement ou un compte inconnu : 404, rien n'est écrit" do
    zadi = create_school_admin(school: create_school)

    sign_in_as @field
    remove zadi, as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('not_found'))}/
    remove zadi
    assert_response :not_found
    delete school_staff_member_path("inconnu", @kofi.public_id), as: :turbo_stream
    assert_response :not_found
    delete school_staff_member_path(@school.public_id, "inconnu"), as: :turbo_stream
    assert_response :not_found
    assert_nothing_written
  end

  test "déjà retiré (deux onglets) : 404" do
    sign_in_as @field
    remove @kofi, as: :turbo_stream
    assert_response :success

    remove @kofi, as: :turbo_stream
    assert_response :not_found
    assert_equal 1, Orm::AuditEvent.where(action: "school_staff.archived").count
  end

  test "hors de l'équipe : 403 ; le visiteur va à « Se connecter »" do
    remove @kofi
    assert_redirected_to new_session_path

    sign_in_as @aya
    remove @kofi, as: :turbo_stream
    assert_response :forbidden
    assert_nothing_written

    [ create_student, create_teacher(school: @school) ].each do |user|
      sign_in_as user
      remove @kofi, as: :turbo_stream
      assert_response :forbidden
    end
    assert_nothing_written
  end

  # Revue de sécurité du Lot C, constat 4 : un membre dont le second facteur n'est pas vérifié n'atteint jamais le retrait.
  test "a team member whose second factor is not verified is sent to it, and nothing is written" do
    post session_path, params: { session: { contact: @field.contact, pin: "2468" } }

    remove @kofi

    assert_redirected_to new_identity_second_factor_path
    assert_nothing_written
  end

  test "an admin removes a direction too, even from an inactive school" do
    @school.update!(status: "inactive")
    sign_in_as create_team_member(team_role: "admin")

    remove @aya, as: :turbo_stream

    assert_response :success
    assert_not_nil staff_of(@aya).archived_at
  end

  # suites-inscription-direction (1) : le retrait d'une femme se dit au féminin, celui d'un homme au masculin.
  test "the removal is said in the gender of the person removed" do
    sign_in_as @field

    remove @aya, as: :turbo_stream
    assert_select "turbo-stream[action=append][target=toasts]", text: /Aya Koné a été retirée de la direction\./
    assert_select "li#school_archived_staff_#{@aya.public_id}", text: /Retirée le .+ · Supprimée le /

    remove @kofi, as: :turbo_stream
    assert_select "turbo-stream[action=append][target=toasts]", text: /Kofi Yao a été retiré de la direction\./
    assert_select "li#school_archived_staff_#{@kofi.public_id}", text: /Retiré le .+ · Supprimé le /
  end
end
