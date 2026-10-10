require "test_helper"

# ADR-0088, UDR-0083, PRD §4 : l'équipe archive d'un coup les classes actives d'un niveau depuis son menu ⋮, en un seul événement d'audit.
class Teams::LevelArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
    @levels = seed_referential[:levels]
    @school = create_school(name: "Lycée Classique d'Abidjan", school_type: "public", cycle: "both")
    @active = (1..5).map { create_classroom(school: @school, level: @levels["6eme"], name: "6ème #{it}") }
    @archived = create_classroom(school: @school, level: @levels["6eme"], name: "6ème 6")
    @archived.update_columns(status: "archived", archived_at: 2.days.ago)
    @fifth = create_classroom(school: @school, level: @levels["5eme"], name: "5ème 1")
  end

  def tc(key, **) = I18n.t("teams.level_archivals.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def path(school = @school) = school_level_archivals_path(school.public_id)

  test "droits : un élève, un enseignant ou une direction reçoivent 403, et rien n'est écrit" do
    [ create_student, create_teacher(school: @school), create_school_admin(school: @school) ].each do |outsider|
      sign_in_as outsider

      post path, params: { level: "6eme" }, as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal 6, Orm::Classroom.where(status: "active").count
    assert_equal 0, Orm::AuditEvent.count
  end

  test "un établissement inconnu ou un niveau inconnu donnent 404" do
    sign_in_as @member

    post school_level_archivals_path("inconnu"), params: { level: "6eme" }, as: :turbo_stream
    assert_response :not_found
    post path, params: { level: "inconnu" }, as: :turbo_stream
    assert_response :not_found
    assert_equal 0, Orm::AuditEvent.count
  end

  test "archiver un niveau : les 5 actives archivées, l'archivée et l'autre niveau intacts, un seul événement d'audit pour 5 classes" do
    archived_at = @archived.reload.archived_at
    sign_in_as @member

    post path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :success
    assert_equal [ "archived" ] * 5, @active.map { it.reload.status }
    assert_equal archived_at, @archived.reload.archived_at
    assert_equal "active", @fifth.reload.status
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("create.done", count: 5))
    assert_equal "5 classes archivées.", tc("create.done", count: 5)
    assert_select "turbo-stream[action=replace][target=level_6eme][method=morph]"
    assert_select "turbo-stream[action=replace] template #level-menu-6eme", false
    assert_select "turbo-stream[action=refresh]:not([request-id])"
    event = Orm::AuditEvent.sole
    assert_equal [ "level_archived", 5 ], [ event.metadata["change"], event.metadata["classrooms_count"] ]
  end

  test "un niveau sans classe active : 422 « rien à archiver », rien n'est écrit" do
    sign_in_as @member
    post path, params: { level: "6eme" }, as: :turbo_stream

    post path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tc("errors.nothing_to_archive"))
    assert_select "turbo-stream[action=refresh]", false
    assert_equal 1, Orm::AuditEvent.count
  end

  test "sans JavaScript : redirection vers la fiche avec un message, succès comme refus" do
    sign_in_as @member

    post path, params: { level: "5eme" }
    assert_redirected_to school_path(@school.public_id)
    assert_equal "1 classe archivée.", flash[:notice]
    post path, params: { level: "5eme" }
    assert_equal tc("errors.nothing_to_archive"), flash[:alert]
  end
end
