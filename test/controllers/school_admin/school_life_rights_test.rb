require "test_helper"

# ED-04, ED-30 to ED-36 (ADR-0092 §4.3, UDR-0092 §3.2, §3.5): an educator or a secretary (rank « vie scolaire ») reads the
# whole direction space and keeps the gestures on students, but neither touches the structure, nor the teachers, nor the
# directions: the gestures are not drawn, a note says why, and a forged request gets 403 with nothing written. The head of
# school and the deputy keep every gesture; the team keeps its own.
class SchoolAdmin::SchoolLifeRightsTest < ActionDispatch::IntegrationTest
  setup do
    referential = seed_referential
    @levels = referential[:levels]
    @school = create_school(name: "Lycée Moderne de Bouaké", school_type: "public", cycle: "both")
    @sixths = (1..4).map { create_classroom(school: @school, level: @levels["6eme"], name: "6ème #{it}") }
    @head = create_school_admin(school: @school, first_name: "Kofi", last_name: "Yao", position: "head", joined_at: 40.days.ago)
    @secretary = create_school_admin(school: @school, first_name: "Awa", last_name: "Koné", position: "secretary", joined_at: 30.days.ago)
    @educator = create_school_admin(school: @school, first_name: "Aya", last_name: "Diallo", position: "educator", joined_at: 30.days.ago)
    @teacher = create_teacher(school: @school, classrooms: [ @sixths.first ], first_name: "Jean", last_name: "Kouamé")
    @departed = create_teacher(school: nil, first_name: "Paul", last_name: "Brou")
    create_teacher_departure(teacher: @departed, school: @school, detached_by: @head)
  end

  def label(key) = I18n.t("shared.staff_positions.#{key}")
  def note(position) = I18n.t("school_admin.shared.rank_note", position: label(position))
  def forbidden_toast = I18n.t("school_admin.shared.errors.forbidden")

  test "ED-04: the « Direction » block shows each position under the name, the deputy as a public school says it" do
    deputy = create_school_admin(school: @school, first_name: "Marc", last_name: "Aka", position: "deputy")
    sign_in_as @head

    get school_admin_school_path

    assert_select "li#school_staff_#{@secretary.public_id} p.text-xs", text: /#{label("secretary")}\s+·/
    assert_select "li#school_staff_#{@head.public_id} p.text-xs", text: /#{Regexp.escape(label("head"))}/
    assert_select "li#school_staff_#{deputy.public_id} p.text-xs", text: /#{Regexp.escape(label("deputy_public"))}/
    assert_select "#rank_note", 0
  end

  test "ED-33: a secretary sees no « + », « − », archiving, withdrawal nor reinstatement; the note says why; the links stay" do
    sign_in_as @secretary

    get school_admin_school_path
    assert_select "#rank_note", text: note("secretary")
    assert_select "#school_level_classrooms form", 0
    assert_select "#school_level_classrooms dialog", 0
    assert_select "#school_staff [aria-haspopup]", 0
    assert_select "#school_staff form", 0
    assert_select "#school_link [data-controller=clipboard]"
    assert_select "#school_link_whatsapp"

    get school_admin_level_path("6eme")
    assert_select "#rank_note", text: note("secretary")
    assert_select "form[action='#{school_admin_level_archivals_path}']", 0
    assert_select "form[action*='classroom-archivals']", 0

    get school_admin_teachers_path
    assert_select "#rank_note", text: note("secretary")
    assert_select "#teacher_#{@teacher.public_id}"
    assert_select "a[href='#{school_admin_teacher_removal_path(@teacher.public_id)}']", 0

    get school_admin_departed_teachers_path
    assert_select "#rank_note", text: note("secretary")
    assert_select "#departed_teacher_#{@departed.public_id}"
    assert_select "form[action='#{school_admin_teacher_reinstatement_path(@departed.public_id)}']", 0
  end

  test "ED-30: forged « + », « − », archiving, restoring and level archiving get 403; nothing is created nor archived" do
    archived = create_classroom(school: @school, level: @levels["5eme"], name: "5ème 1", status: "archived", archived_at: 1.day.ago)
    sign_in_as @secretary

    post school_admin_level_classrooms_path, params: { level: "6eme", series: "" }, as: :turbo_stream
    assert_response :forbidden
    delete school_admin_level_classroom_path(@sixths.last.public_id), as: :turbo_stream
    assert_response :forbidden
    patch archive_school_admin_classroom_archival_path(@sixths.last.public_id), as: :turbo_stream
    assert_response :forbidden
    patch restore_school_admin_classroom_archival_path(archived.public_id), as: :turbo_stream
    assert_response :forbidden
    post school_admin_level_archivals_path, params: { level: "6eme" }, as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]"

    assert_equal 4, Orm::Classroom.where(school: @school, level: @levels["6eme"], status: "active").count
    assert_equal "archived", archived.reload.status
    assert_not Orm::AuditEvent.exists?
  end

  test "ED-31: forged withdrawal and reinstatement of a teacher get 403; the attachments do not change" do
    sign_in_as @educator

    get school_admin_teacher_removal_path(@teacher.public_id), headers: { "Turbo-Frame" => "modal" }
    assert_response :forbidden
    delete school_admin_teacher_path(@teacher.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(forbidden_toast)}/
    post school_admin_teacher_reinstatement_path(@departed.public_id), as: :turbo_stream
    assert_response :forbidden

    assert Orm::TeacherSchool.exists?(teacher: @teacher, school: @school)
    assert_not Orm::TeacherSchool.exists?(teacher: @departed)
  end

  test "ED-32: a secretary there for 30 days cannot remove the head of school" do
    sign_in_as @secretary

    delete school_admin_staff_member_path(@head.public_id), as: :turbo_stream

    assert_response :forbidden
    assert_nil Orm::SchoolStaff.find_by!(user_id: @head.id).archived_at
  end

  test "ED-34: an educator keeps the classroom page, its link and the withdrawal of a student" do
    student = create_student(classroom: @sixths.first, first_name: "Aya", last_name: "Kouassi")
    sign_in_as @educator

    get school_admin_classroom_path(@sixths.first.public_id)
    assert_response :success
    assert_select "#rank_note", 0
    assert_select ".ui-menu-item span", text: I18n.t("classroom.classrooms.link.change")
    assert_select ".ui-menu-item span", text: I18n.t("classroom.classrooms.roster.remove")

    delete classroom_student_path(@sixths.first.public_id, student.public_id), as: :turbo_stream
    assert_response :success
    assert_not_nil Orm::ClassroomStudent.find_by!(student:, classroom: @sixths.first).left_at
  end

  test "ED-33: the note appears only where the page has a gesture to hide: an empty « Enseignants » page of an educator has none" do
    school = create_school(school_type: "public", cycle: "both")
    educator = create_school_admin(school: school, position: "educator")
    sign_in_as educator

    get school_admin_teachers_path
    assert_response :success
    assert_select "#rank_note", 0

    get school_admin_departed_teachers_path
    assert_response :success
    assert_select "#rank_note", 0

    classroom = create_classroom(school:, level: @levels["6eme"], name: "6ème 1")
    create_teacher(school:, classrooms: [ classroom ])
    get school_admin_teachers_path
    assert_select "#rank_note", text: note("educator")

    get school_admin_level_path("6eme")
    assert_select "#rank_note", text: note("educator")
  end

  test "ED-35: the head and the deputy add a classroom, archive one and withdraw a teacher, as before" do
    deputy = create_school_admin(school: @school, position: "deputy")
    [ @head, deputy ].each_with_index do |admin, index|
      sign_in_as admin
      get school_admin_school_path
      assert_select "#school_level_classrooms form[action='#{school_admin_level_classrooms_path}']"

      post school_admin_level_classrooms_path, params: { level: "6eme", series: "" }, as: :turbo_stream
      assert_response :success
      patch archive_school_admin_classroom_archival_path(@sixths[index + 1].public_id), as: :turbo_stream
      assert_response :success
      sign_out
    end
    sign_in_as deputy
    delete school_admin_teacher_path(@teacher.public_id), as: :turbo_stream
    assert_response :success
    assert_not Orm::TeacherSchool.exists?(teacher: @teacher, school: @school)
  end

  test "ED-36: the team still adds a classroom and removes a direction" do
    admin = create_team_member(team_role: "admin")
    sign_in_as admin

    post school_level_classrooms_path(@school.public_id), params: { level: "6eme", series: "" }, as: :turbo_stream
    assert_response :success
    delete school_staff_member_path(@school.public_id, @secretary.public_id), as: :turbo_stream
    assert_response :success
    assert_not_nil Orm::SchoolStaff.find_by!(user_id: @secretary.id).archived_at
  end
end
