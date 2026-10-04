require "test_helper"

# ID-19 to ID-21 (ADR-0077 §4.3, UDR-0070 §3.5): the admin or field team restores a removed direction of a school. An
# arrival by the code is refused (409) while 3 directions by the code are active; an invited direction always comes back.
# A content member is refused (403); a direction of another school is not found.
class Teams::SchoolStaffRestorationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_team_member(team_role: "admin")
    @kofi = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", joined_via: "code", joined_at: 30.days.ago)
    @aya = create_school_admin(school: @school, first_name: "Aya", last_name: "Koné", joined_via: "code", joined_at: 20.days.ago,
                               archived_at: 2.days.ago)
  end

  def ts(key, **) = I18n.t("teams.school_staff_restorations.create.#{key}", **)
  def staff_of(user) = Orm::SchoolStaff.find_by!(user_id: user.id)
  def restore(user, school: @school, **) = post(school_staff_member_restoration_path(school.public_id, user.public_id), **)

  test "ID-19 : 2 actives par le code : l'admin restaure Aya ; elle revient dans « Direction », peut se connecter, journal" do
    create_school_admin(school: @school, joined_via: "code")

    sign_in_as @admin
    restore @aya, as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('done', name: 'Aya Koné'))}/
    # Phase 5 : la dernière restaurée, la carte « Directions retirées » laisse place à sa cible vide, comme au rechargement.
    assert_select "turbo-stream[action=replace][target=school_archived_staff] template" do
      assert_select "div#school_archived_staff:empty"
      assert_select "h2", 0
    end
    assert_select "turbo-stream[action=replace][target=school_staff] template #school_staff" do
      assert_select "p#school_staff_places", text: I18n.t("shared.school_staff.subtitle", used: 3, cap: 3)
      assert_select "li#school_staff_#{@aya.public_id}", text: /Aya Koné/ do
        assert_select "button[aria-haspopup=menu]"
      end
    end
    assert_nil staff_of(@aya).archived_at
    event = Orm::AuditEvent.find_by!(action: "school_staff.restored")
    assert_equal [ @admin.id, "User", @aya.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "school_id" => @school.id, "joined_via" => "code" }, event.metadata)

    sign_out
    sign_in_as @aya
    assert_redirected_to school_admin_classrooms_path
  end

  test "ID-20 : 3 actives par le code : 409, toast du plafond, Aya reste archivée ; une invitée se restaure" do
    2.times { create_school_admin(school: @school, joined_via: "code") }
    awa = create_school_admin(school: @school, first_name: "Awa", last_name: "Diallo", archived_at: 1.day.ago)

    sign_in_as create_team_member(team_role: "field")
    restore @aya, as: :turbo_stream
    assert_response :conflict
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(ts('cap_reached'))}/
    assert_not_nil staff_of(@aya).archived_at
    assert_not Orm::AuditEvent.exists?(action: "school_staff.restored")

    restore @aya
    assert_redirected_to school_path(@school.public_id)
    assert_equal ts("cap_reached"), flash[:alert]

    restore awa, as: :turbo_stream
    assert_response :success
    assert_nil staff_of(awa).archived_at
  end

  test "repli HTML : 303 vers la fiche, avec la notice" do
    sign_in_as @admin
    restore @aya

    assert_redirected_to school_path(@school.public_id)
    assert_equal 303, response.status
    assert_equal ts("done", name: "Aya Koné"), flash[:notice]
  end

  test "ID-21 : un POST forgé d'un membre content répond 403, rien n'est écrit" do
    sign_in_as create_team_member(team_role: "content")
    restore @aya, as: :turbo_stream

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t('shared.school_staff.forbidden'))}/
    restore @aya
    assert_response :forbidden
    assert_not_nil staff_of(@aya).archived_at
  end

  test "déjà active, d'un autre établissement, ou inconnue : 404, rien n'est écrit" do
    zadi = create_school_admin(school: create_school, archived_at: 1.day.ago)

    sign_in_as @admin
    restore @kofi, as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t('shared.school_staff.not_found'))}/
    restore zadi, as: :turbo_stream
    assert_response :not_found
    restore zadi
    assert_response :not_found
    post school_staff_member_restoration_path("inconnu", @aya.public_id), as: :turbo_stream
    assert_response :not_found
    assert_not_nil staff_of(zadi).archived_at
    assert_not Orm::AuditEvent.exists?(action: "school_staff.restored")
  end

  test "another removed direction left: the card stays, without the restored line" do
    salif = create_school_admin(school: @school, first_name: "Salif", last_name: "Traoré", archived_at: 1.day.ago)
    sign_in_as @admin

    restore @aya, as: :turbo_stream

    assert_select "turbo-stream[action=replace][target=school_archived_staff] template #school_archived_staff" do
      assert_select "li#school_archived_staff_#{salif.public_id}"
      assert_select "li#school_archived_staff_#{@aya.public_id}", 0
    end
  end

  test "hors de l'équipe : 403 ; le visiteur va à « Se connecter »" do
    restore @aya
    assert_redirected_to new_session_path

    sign_in_as @kofi
    restore @aya, as: :turbo_stream
    assert_response :forbidden

    [ create_student, create_teacher(school: @school) ].each do |user|
      sign_in_as user
      restore @aya, as: :turbo_stream
      assert_response :forbidden
    end
    assert_not_nil staff_of(@aya).archived_at
    assert_not Orm::AuditEvent.exists?(action: "school_staff.restored")
  end

  # Revue de sécurité du Lot C, constat 4 : un membre dont le second facteur n'est pas vérifié n'atteint jamais la restauration.
  test "a team member whose second factor is not verified is sent to it, and nothing is restored" do
    member = create_team_member(team_role: "admin")
    post session_path, params: { session: { contact: member.contact, pin: "2468" } }

    restore @aya

    assert_redirected_to new_identity_second_factor_path
    assert_not_nil staff_of(@aya).archived_at
    assert_not Orm::AuditEvent.exists?(action: "school_staff.restored")
  end
end
