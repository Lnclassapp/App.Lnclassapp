require "test_helper"

# GD-23 to GD-26 (ADR-0071 §4.3, UDR-0056 §3.5): from the waiting screen, a teacher without a school types the code of
# an active school and lands on the choice of their classes; the school that detached them, an unknown code and a school
# not active read the same error; ten tries a minute; a pending request is refused.
class Identity::PendingSchoolJoinsControllerTest < ActionDispatch::IntegrationTest
  INVALID = "Code d'établissement invalide. Vérifiez-le auprès de votre établissement.".freeze

  setup do
    @a = create_school(name: "Lycée Moderne de Bouaké", school_code: "k7m4qz")
    @b = create_school(name: "Lycée Classique d'Abidjan", school_code: "abc234")
    @teacher = create_teacher(school: nil)
    create_teacher_departure(teacher: @teacher, school: @a, detached_by: create_school_admin(school: @a))
  end

  def t(key, **) = I18n.t("identity.pending_accounts.show.#{key}", **)
  def join(code) = post(pending_school_join_path, params: { school_join: { school_code: code } })

  test "GD-23 : le code de B, saisi n'importe comment : rattaché à B, vers le choix de ses classes, journal" do
    sign_in_as @teacher

    join("abc 234")

    assert_redirected_to teacher_classrooms_path
    assert_response :see_other
    assert_equal I18n.t("identity.pending_school_joins.create.welcome", school: "Lycée Classique d'Abidjan"), flash[:notice]
    assert_equal [ [ @b.id, true ] ], Orm::TeacherSchool.where(teacher: @teacher).pluck(:school_id, :primary)
    assert Orm::AuditEvent.exists?(action: "school.changed", actor_id: @teacher.id, subject_type: "School", subject_id: @b.id,
                                   metadata: { "change" => "teacher_joined" })
    follow_redirect!
    assert_response :success
  end

  test "GD-24 : le code de A, un code inconnu, un établissement inactif : trois fois le même message, toujours sans établissement" do
    create_school(school_code: "zzz999", status: "inactive")
    sign_in_as @teacher

    [ "K7M-4QZ", "xyz789", "zzz999" ].each do |code|
      join(code)

      assert_response :unprocessable_entity
      assert_select "form#school-join-form[action='#{pending_school_join_path}']" do
        assert_select "input[name='school_join[school_code]'][value=?][aria-invalid=true]", code
        assert_select "#school_join_school_code_error", text: INVALID
      end
      assert_select "h1", text: t("no_school.title")
    end
    assert_empty Orm::TeacherSchool.where(teacher: @teacher)
  end

  test "une saisie vide : 422, le motif sous le champ" do
    sign_in_as @teacher

    join("")

    assert_response :unprocessable_entity
    assert_select "#school_join_school_code_error", text: "Saisissez le code de votre établissement."
  end

  test "GD-25 : une 11ᵉ tentative dans la minute : 429 « Trop de tentatives », sans formulaire" do
    sign_in_as @teacher

    10.times { join("xyz789") }
    assert_response :unprocessable_entity

    join("abc234")

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

    join("abc234")

    assert_response :forbidden
    assert_equal "pending", request.reload.status
    assert_empty Orm::TeacherSchool.where(teacher: pending)
  end

  test "un enseignant déjà rattaché, un élève, une direction : 403" do
    [ create_teacher(school: @a), create_student, create_school_admin(school: @a) ].each do |user|
      sign_in_as user
      join("abc234")
      assert_response :forbidden, user.role
      sign_out
    end
  end

  test "un visiteur se connecte d'abord" do
    join("abc234")

    assert_redirected_to new_session_path
  end
end
