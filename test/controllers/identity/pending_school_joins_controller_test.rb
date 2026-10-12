require "test_helper"

# IE-18 (ADR-0083 §4.3, UDR-0079 §3.9) on GD-23 to GD-26 (ADR-0071 §4.3): from the waiting screen, a teacher without a
# school chooses a DRENA, then an active school of it, and lands on their home; the school that detached them, an inactive
# school and a school of another DRENA read the same neutral error; ten tries a minute; a pending request is refused.
class Identity::PendingSchoolJoinsControllerTest < ActionDispatch::IntegrationTest
  NEUTRAL = "Cet établissement ne peut pas être rejoint.".freeze

  setup do
    @abidjan = create_drena(name: "Abidjan 1")
    @a = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
    @b = create_school(drena: @abidjan, name: "Lycée Classique d'Abidjan")
    @teacher = create_teacher(school: nil)
    create_teacher_departure(teacher: @teacher, school: @a, detached_by: create_school_admin(school: @a))
  end

  def t(key, **) = I18n.t("identity.pending_accounts.show.#{key}", **)

  def join(school, drena: @abidjan)
    post pending_school_join_path, params: { school_join: { drena_public_id: drena&.public_id, school_public_id: school&.public_id } }
  end

  test "IE-18 : la DRENA puis le Lycée Classique : rattaché en école principale, sur son accueil, journal" do
    sign_in_as @teacher

    join(@b)

    assert_redirected_to teacher_home_path
    assert_response :see_other
    assert_equal I18n.t("identity.pending_school_joins.create.welcome", school: "Lycée Classique d'Abidjan"), flash[:notice]
    assert_equal [ [ @b.id, true ] ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id, :primary)
    assert Orm::AuditEvent.exists?(action: "school.changed", actor_id: @teacher.id, subject_type: "School", subject_id: @b.id,
                                   metadata: { "change" => "teacher_joined" })
    follow_redirect!
    assert_response :success
  end

  test "IE-18 : un enseignant jamais configuré rejoint, puis choisit ses classes" do
    teacher = create_teacher(school: nil, onboarded: false)
    sign_in_as teacher

    join(@b)

    assert_redirected_to teacher_classrooms_path
  end

  test "IE-18 : l'établissement qui l'a retiré, un inactif, un d'une autre DRENA : 422, la même erreur neutre, rien de rejoint" do
    inactive = create_school(drena: @abidjan, name: "Lycée fermé", status: "inactive")
    elsewhere = create_school(name: "Lycée de Bouaké")
    sign_in_as @teacher

    [ @a, inactive, elsewhere ].each do |school|
      join(school)

      assert_response :unprocessable_entity
      assert_select "h1", text: t("no_school.title")
      assert_select "form#school-join-form[action='#{pending_school_join_path}']" do
        assert_select "#school_join_school_public_id_error", text: NEUTRAL
        assert_select "select#school_join_school_public_id[aria-invalid=true]"
        assert_select "input[type=hidden][name='school_join[drena_public_id]'][value=?]", @abidjan.public_id
      end
      assert_select "select#school_join_drena_public_id option[selected][value=?]", @abidjan.public_id
      assert_select "input[name*=school_code]", 0
    end
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)
  end

  test "un établissement choisi garde son choix au re-rendu" do
    sign_in_as @teacher

    join(@a)

    assert_select "select#school_join_school_public_id option[selected][value=?]", @a.public_id
  end

  test "sans DRENA ni établissement : 422, chaque motif sous son champ" do
    sign_in_as @teacher

    post pending_school_join_path

    assert_response :unprocessable_entity
    assert_select "#school_join_drena_public_id_error", text: "Choisissez votre DRENA."
    assert_select "#school_join_school_public_id_error", text: "Choisissez votre établissement."
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)
  end

  test "GD-25 : une 11ᵉ tentative dans la minute : 429 « Trop de tentatives », sans formulaire" do
    sign_in_as @teacher

    10.times { join(@a) }
    assert_response :unprocessable_entity

    join(@b)

    assert_response :too_many_requests
    assert_select "[role=alert]", text: /#{t('rate_limited.title')}/
    assert_select "[role=alert]", text: /#{t('rate_limited.message')}/
    assert_select "form#school-join-form", 0
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)
  end

  test "GD-26 : un enseignant dont la demande est en attente : 403, la demande reste en attente" do
    pending = create_teacher(school: nil)
    request = create_join_request(school: @a, teacher: pending)
    sign_in_as pending

    join(@b)

    assert_response :forbidden
    assert_equal "pending", request.reload.status
    assert_empty Orm::TeacherSchool.where(teacher: pending)
  end

  test "un enseignant déjà rattaché, un élève, une direction : 403" do
    [ create_teacher(school: @a), create_student, create_school_admin(school: @a) ].each do |user|
      sign_in_as user
      join(@b)
      assert_response :forbidden, user.role
      sign_out
    end
  end

  test "un visiteur se connecte d'abord" do
    join(@b)

    assert_redirected_to new_session_path
  end
end
