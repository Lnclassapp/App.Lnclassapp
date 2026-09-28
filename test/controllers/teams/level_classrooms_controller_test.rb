require "test_helper"

# CN-02 à CN-07, CN-09, ADR-0059, UDR-0046 : depuis le bloc « Classes par niveau » de la fiche, l'équipe ajoute la
# classe suivante d'un niveau ou retire la dernière ; le bloc est remplacé en Turbo Stream et la fiche re-demandée.
class Teams::LevelClassroomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    referential = seed_referential
    @levels = referential[:levels]
    @series = referential[:series]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    @sixths = (1..4).map { create_classroom(school: @school, level: @levels["6eme"], name: "6ème #{it}") }
  end

  # PRD §4 : les messages passent par leur clé de locale.
  def tc(key, **) = I18n.t("teams.level_classrooms.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def add_path(school = @school) = school_level_classrooms_path(school.public_id)
  def remove_path(classroom, school = @school) = school_level_classroom_path(school.public_id, classroom.public_id)

  test "CN-09 : un élève, un enseignant ou une direction reçoivent 403, et rien n'est écrit" do
    [ create_student, create_teacher(school: @school), create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      post add_path, params: { level: "6eme" }, as: :turbo_stream
      assert_response :forbidden
      delete remove_path(@sixths.last), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal 4, Orm::Classroom.count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "un établissement inconnu donne 404" do
    sign_in_as @member

    post school_level_classrooms_path("inconnu"), params: { level: "6eme" }, as: :turbo_stream
    assert_response :not_found
    delete school_level_classroom_path("inconnu", @sixths.last.public_id), as: :turbo_stream
    assert_response :not_found
  end

  test "CN-02 : « + » crée la 6ème 5 de l'année, tracée ; toast avec le code, bloc remplacé, fiche re-demandée" do
    sign_in_as @member

    post add_path, params: { level: "6eme", series: "" }, as: :turbo_stream

    assert_response :success
    classroom = Orm::Classroom.find_by!(name: "6ème 5")
    assert_equal [ @school.id, @levels["6eme"].id, nil, current_school_year, "active", 80 ],
                 [ classroom.school_id, classroom.level_id, classroom.series_id, classroom.school_year, classroom.status,
                   classroom.max_students ]
    assert_match Entities::Classroom::JoinCode::FORMAT, classroom.join_code
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(tc("create.done", name: "6ème 5", code: classroom.join_code.upcase))
    assert_select "turbo-stream[action=replace][target=school_level_classrooms][method=morph]"
    assert_select "turbo-stream[action=replace] template #level_classrooms_6eme [role=group][aria-label=?]",
                  tc("block.count", level: "6ème", count: 5)
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @member.id, "School", @school.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "classroom_added", "classroom_public_id" => classroom.public_id, "name" => "6ème 5" }, event.metadata)
  end

  test "CN-03 : une série suit sa propre numérotation" do
    create_classroom(school: @school, level: @levels["tle"], series: @series["d"], name: "Tle D 3")
    sign_in_as @member

    post add_path, params: { level: "tle", series: "d" }, as: :turbo_stream

    assert_response :success
    assert Orm::Classroom.exists?(school: @school, name: "Tle D 4", series: @series["d"])
  end

  test "CN-04 : un brouillon, ou une série fermée au niveau, sont refusés en 422 avec le motif, bloc re-rendu" do
    draft = create_school(status: "draft")
    sign_in_as @member

    post add_path(draft), params: { level: "6eme" }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.school_draft"))
    assert_select "turbo-stream[action=replace][target=school_level_classrooms]"
    assert_select "turbo-stream[action=refresh]", 0

    post add_path, params: { level: "6eme", series: "d" }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.invalid"))

    assert_equal 4, Orm::Classroom.count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "CN-05 : « − » supprime la dernière classe vide, tracée ; toast, bloc remplacé, fiche re-demandée" do
    sign_in_as @member

    delete remove_path(@sixths.last), as: :turbo_stream

    assert_response :success
    assert_not Orm::Classroom.exists?(@sixths.last.id)
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("destroy.done", name: "6ème 4"))
    assert_select "turbo-stream[action=replace] template #level_classrooms_6eme [role=group][aria-label=?]",
                  tc("block.count", level: "6ème", count: 3)
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    assert_equal({ "change" => "classroom_removed", "classroom_public_id" => @sixths.last.public_id, "name" => "6ème 4" },
                 Orm::AuditEvent.sole.metadata)
  end

  test "CN-06 : une classe qui a un élève est refusée : 422, « archivez-la plutôt », rien n'est supprimé" do
    create_student(classroom: @sixths.last)
    sign_in_as @member

    delete remove_path(@sixths.last), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.has_students"))
    assert_select "turbo-stream[action=replace] template #level_classrooms_6eme [role=group][aria-label=?]",
                  tc("block.count", level: "6ème", count: 4)
    assert Orm::Classroom.exists?(@sixths.last.id)
    assert_equal 0, Orm::AuditEvent.count
  end

  test "CN-07 : une classe qui n'est plus la dernière est refusée ; une classe déjà retirée donne 404" do
    sign_in_as @member

    delete remove_path(@sixths.first), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.not_last"))

    delete remove_path(@sixths.last), as: :turbo_stream
    delete remove_path(@sixths.last), as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.not_found"))
    assert_select "turbo-stream[action=replace][target=school_level_classrooms]"
    assert_equal 3, Orm::Classroom.count
  end

  test "sans Turbo : retour à la fiche, avec le message en flash" do
    sign_in_as @member

    post add_path, params: { level: "6eme" }
    assert_redirected_to school_path(@school.public_id)
    assert_equal tc("create.done", name: "6ème 5", code: Orm::Classroom.find_by!(name: "6ème 5").join_code.upcase), flash[:notice]

    delete remove_path(@sixths.first)
    assert_redirected_to school_path(@school.public_id)
    assert_equal tc("errors.not_last"), flash[:alert]

    delete remove_path(Orm::Classroom.find_by!(name: "6ème 5"))
    assert_equal tc("destroy.done", name: "6ème 5"), flash[:notice]
  end
end
