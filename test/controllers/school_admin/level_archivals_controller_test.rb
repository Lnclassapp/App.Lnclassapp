require "test_helper"

# ADR-0088, UDR-0083 (PRD §4) : « Archiver le niveau » archive d'un coup les classes actives du niveau dans l'établissement
# de la direction (toutes séries, année en cours), en un seul événement d'audit ; le niveau est donné par son slug.
class SchoolAdmin::LevelArchivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Collège Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
    @level = create_level(name: "6ème", position: 1)
    @other_level = create_level(name: "5ème", position: 2)
    @actives = (1..5).map { create_classroom(school: @school, level: @level, name: "6ème #{it}") }
    @actives.each { create_student(classroom: it) }
    @archived = create_classroom(school: @school, level: @level, name: "6ème 6", status: "archived", archived_at: 20.days.ago)
  end

  def tl(key, **) = I18n.t("school_admin.level_archivals.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def statuses(scope = Orm::Classroom) = scope.order(:name).pluck(:status)

  test "the 5 active classrooms are archived, the archived one is not touched, one audit event says 5" do
    untouched_at = Orm::Classroom.find(@archived.id).archived_at
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :success
    assert_equal %w[archived] * 6, statuses
    assert_equal untouched_at, Orm::Classroom.find(@archived.id).archived_at
    assert_equal 5, Orm::ClassroomStudent.where(left_at: nil).count
    event = Orm::AuditEvent.sole
    assert_equal [ "school.changed", @admin.id, "School", @school.id ], [ event.action, event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "change" => "level_archived", "level_id" => @level.id, "classrooms_count" => 5 }, event.metadata)
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.done", count: 5, name: "6ème"))
    assert_select "turbo-stream[action=refresh]", count: 1
  end

  test "the other levels, other schools and past years are left alone" do
    other_level_classroom = create_classroom(school: @school, level: @other_level, name: "5ème 1")
    foreign = create_classroom(school: create_school(name: "Lycée Classique d'Abidjan"), level: @level, name: "6ème 1")
    past = create_classroom(school: @school, level: @level, name: "6ème 9", school_year: "2020-2021")
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream

    assert_equal %w[active] * 3, [ other_level_classroom, foreign, past ].map { Orm::Classroom.find(it.id).status }
  end

  test "one classroom: the toast is in the singular" do
    @actives.drop(1).each { it.update!(status: "archived", archived_at: 1.day.ago) }
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream

    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.done", count: 1, name: "6ème"))
  end

  test "without JavaScript: back to the page of the level with a flash notice" do
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }

    assert_redirected_to school_admin_level_path("6eme")
    assert_equal tl("create.done", count: 5, name: "6ème"), flash[:notice]
  end

  test "a level without active classroom is a conflict, nothing is written" do
    Orm::Classroom.where(school: @school).update_all(status: "archived", archived_at: 1.day.ago)
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("errors.nothing_to_archive"))
    assert_select "turbo-stream[action=refresh]", count: 1
    assert_equal 0, Orm::AuditEvent.count
  end

  test "without JavaScript, a refusal is a flash alert on the page of the level" do
    Orm::Classroom.where(school: @school).update_all(status: "archived", archived_at: 1.day.ago)
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }

    assert_redirected_to school_admin_level_path("6eme")
    assert_equal tl("errors.nothing_to_archive"), flash[:alert]
  end

  test "an unknown level, or none, is not found, nothing is written" do
    sign_in_as @admin

    [ { level: "7eme" }, {}, { level: [ "6eme" ] } ].each do |params|
      post school_admin_level_archivals_path, params:, as: :turbo_stream

      assert_response :not_found, params.inspect
    end
    assert_equal %w[active] * 5 + %w[archived], statuses
  end

  test "a direction of an inactive school is refused, nothing is written" do
    @school.update!(status: "inactive")
    sign_in_as @admin

    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream

    assert_response :forbidden
    assert_equal %w[active] * 5 + %w[archived], statuses
    assert_equal 0, Orm::AuditEvent.count
  end

  test "a student, a teacher, a team member and a detached school admin receive 403; a visitor is sent to sign in" do
    [ create_student, create_teacher(school: @school), create_team_member, create_user(role: "school_admin") ].each do |outsider|
      sign_in_as outsider

      post school_admin_level_archivals_path, params: { level: "6eme" }

      assert_response :forbidden, outsider.role
      sign_out
    end
    post school_admin_level_archivals_path, params: { level: "6eme" }

    assert_redirected_to new_session_path
    assert_equal %w[active] * 5 + %w[archived], statuses
  end
end
