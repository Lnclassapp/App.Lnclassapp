require "test_helper"

# GD-08 à GD-12 (ADR-0071 §4.2, UDR-0056 §3.0, §3.2) : depuis « Établissement », la direction ajoute la classe suivante
# d'un niveau ou retire la dernière, sur son seul établissement actif ; le bloc « Classes par niveau » est remplacé en
# Turbo Stream avec ses routes, les refus portent les motifs de l'équipe.
class SchoolAdmin::LevelClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    referential = seed_referential
    @levels = referential[:levels]
    @school = create_school(name: "Lycée Moderne de Bouaké", school_type: "public", cycle: "both")
    @admin = create_school_admin(school: @school)
    @sixths = (1..4).map { create_classroom(school: @school, level: @levels["6eme"], name: "6ème #{it}") }
    @other = create_school(name: "Lycée Classique d'Abidjan")
    @other_sixth = create_classroom(school: @other, level: @levels["6eme"], name: "6ème 1")
  end

  def tc(key, **) = I18n.t("teams.level_classrooms.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def sixth_count(count) = [ "turbo-stream[action=replace] template #level_classrooms_6eme [role=group][aria-label=?]",
                             tc("block.count", level: "6ème", count:) ]

  test "GD-08 : « + » crée la « 6ème 5 » dans son établissement, tracée ; toast avec le code, bloc remplacé aux routes de la direction" do
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme", series: "" }, as: :turbo_stream

    assert_response :success
    classroom = Orm::Classroom.find_by!(name: "6ème 5")
    assert_equal [ @school.id, @levels["6eme"].id, current_school_year, "active" ],
                 [ classroom.school_id, classroom.level_id, classroom.school_year, classroom.status ]
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("create.done", name: "6ème 5"))
    assert_select "turbo-stream[action=replace][target=school_level_classrooms][method=morph]"
    assert_select(*sixth_count(5))
    assert_select "turbo-stream[action=replace] template dialog form[action='#{school_admin_level_classroom_path(classroom.public_id)}']"
    assert_select "turbo-stream[action=replace] template form[action='#{school_admin_level_classrooms_path}']"
    assert_select "form[action*='/teams/']", 0
    assert_not_includes response.body, @school.public_id
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @admin.id, "School", @school.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "classroom_added", "classroom_public_id" => classroom.public_id, "name" => "6ème 5" }, event.metadata)
  end

  test "GD-09 : « − » supprime la dernière classe jamais utilisée, tracée ; la ligne affiche 4" do
    fifth = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 5")
    sign_in_as @admin

    delete school_admin_level_classroom_path(fifth.public_id), as: :turbo_stream

    assert_response :success
    assert_not Orm::Classroom.exists?(fifth.id)
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("destroy.done", name: "6ème 5"))
    assert_select(*sixth_count(4))
    assert_equal({ "change" => "classroom_removed", "classroom_public_id" => fifth.public_id, "name" => "6ème 5" },
                 Orm::AuditEvent.sole.metadata)
  end

  test "GD-10 : une classe qui a un élève est refusée en 422 avec le motif de l'équipe, et existe toujours" do
    create_student(classroom: @sixths.last)
    sign_in_as @admin

    delete school_admin_level_classroom_path(@sixths.last.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.has_students"))
    assert_select(*sixth_count(4))
    assert Orm::Classroom.exists?(@sixths.last.id)
    assert_equal 0, Orm::AuditEvent.count
  end

  test "GD-11 : une classe d'un autre établissement passée en public_id donne 404, et rien ne change chez B" do
    sign_in_as @admin

    delete school_admin_level_classroom_path(@other_sixth.public_id), as: :turbo_stream

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.not_found"))
    assert Orm::Classroom.exists?(@other_sixth.id)
    assert_equal 0, Orm::AuditEvent.count
  end

  test "GD-11 : « + » vise toujours l'établissement du compte, jamais un paramètre" do
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme", school_public_id: @other.public_id }, as: :turbo_stream

    assert_response :success
    assert_equal [ @school.id ], Orm::Classroom.where(name: "6ème 5").pluck(:school_id)
    assert_equal 1, Orm::Classroom.where(school: @other).count
  end

  test "GD-12 : établissement inactif : l'ajout et le retrait forgés répondent 403 avec le motif, rien n'est écrit" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme" }, as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.forbidden"))
    assert_select "turbo-stream[action=replace][target=school_level_classrooms]"

    delete school_admin_level_classroom_path(@sixths.last.public_id), as: :turbo_stream
    assert_response :forbidden

    assert_equal 4, Orm::Classroom.where(school: @school).count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "un brouillon : la direction est refusée en 403 comme pour un établissement inactif" do
    @school.update!(status: "draft")
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :forbidden
    assert_equal 4, Orm::Classroom.where(school: @school).count
  end

  test "une série fermée au niveau est refusée en 422 avec le motif" do
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme", series: "d" }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.invalid"))
  end

  test "un élève, un enseignant, l'équipe et une direction sans établissement reçoivent 403 ; un visiteur se connecte" do
    post school_admin_level_classrooms_path, params: { level: "6eme" }
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      post school_admin_level_classrooms_path, params: { level: "6eme" }, as: :turbo_stream
      assert_response :forbidden, user.role
      delete school_admin_level_classroom_path(@sixths.last.public_id), as: :turbo_stream
      assert_response :forbidden, user.role
      sign_out
    end

    assert_equal 4, Orm::Classroom.where(school: @school).count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "sans Turbo : retour à « Établissement », avec le message en flash" do
    sign_in_as @admin

    post school_admin_level_classrooms_path, params: { level: "6eme" }
    assert_redirected_to school_admin_school_path
    assert_response :see_other
    assert_equal tc("create.done", name: "6ème 5"), flash[:notice]

    delete school_admin_level_classroom_path(@sixths.first.public_id)
    assert_redirected_to school_admin_school_path
    assert_equal tc("errors.not_last"), flash[:alert]
  end
end
