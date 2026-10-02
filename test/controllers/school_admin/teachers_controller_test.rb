require "test_helper"

# ADR-0065, UDR-0052 (DS-06, DS-10, DS-11): « Enseignants », read by the direction on its own school only.
# ADR-0071 §4.3, UDR-0056 §3.3 (GD-14 to GD-18): the direction of an active school withdraws one of its teachers.
class SchoolAdmin::TeachersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Bouaké")
    @admin = create_school_admin(school: @school)
  end

  def t(key, **) = I18n.t("school_admin.teachers.index.#{key}", **)

  test "DS-06, DS-10 : la direction voit ses enseignants, leur matière et leurs classes, rien d'un autre établissement" do
    maths = create_material(name: "Mathématiques", category: "science")
    second = create_classroom(school: @school, level: create_level(name: "2nde", position: 5), name: "2nde C 1")
    final = create_classroom(school: @school, level: create_level(name: "Tle", position: 7), name: "Tle D 2")
    awa = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", material: maths, classrooms: [ final, second ])
    idle = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")
    create_teacher(school: @school, first_name: "Anne", last_name: "Anonyme").update!(anonymized_at: Time.current)
    create_join_request(school: @school, teacher: create_teacher(school: nil, first_name: "Paul", last_name: "Attente"))
    other_school = create_school
    create_teacher(school: other_school, first_name: "Jean", last_name: "Ailleurs",
                   classrooms: [ create_classroom(school: other_school, name: "1ère A 3") ])

    sign_in_as @admin
    get school_admin_teachers_path

    assert_response :success
    assert_select "h1", text: t("title")
    assert_select "main", text: /#{Regexp.escape(t('subtitle', school: 'Lycée Moderne de Bouaké', count: 2))}/
    assert_select "nav a[aria-current=page]", text: I18n.t("shared.navigation.teachers")
    assert_select "#school_teachers table" do
      assert_select "caption.sr-only", text: t("caption", school: "Lycée Moderne de Bouaké")
      assert_select "th[scope=col]", 4
      assert_select "tbody tr", 2
      assert_select "tr#teacher_#{idle.public_id} th[scope=row]", text: "Yao Brou"
      assert_select "tr#teacher_#{idle.public_id} td", text: t("no_classroom")
      assert_select "tr#teacher_#{awa.public_id} th[scope=row]", text: "Awa Koné"
      assert_select "tr#teacher_#{awa.public_id} td", text: "Mathématiques"
      assert_select "tr#teacher_#{awa.public_id} td", text: "2nde C 1, Tle D 2"
    end
    [ "Anonyme", "Attente", "Ailleurs", "1ère A 3" ].each { assert_not_includes response.body, it }
    Orm::User.where(role: "teacher").pluck(:contact).compact.each { assert_not_includes response.body, it }
  end

  test "un enseignant sans matière connue : « — » lu « non calculé »" do
    teacher = create_user(role: "teacher", first_name: "Awa", last_name: "Koné")
    Orm::TeacherSchool.create!(teacher:, school: @school, primary: true)

    sign_in_as @admin
    get school_admin_teachers_path

    assert_select "tr#teacher_#{teacher.public_id} td span[aria-hidden=true]", text: "—"
    assert_select "tr#teacher_#{teacher.public_id} td span.sr-only", text: t("missing")
  end

  test "un établissement sans enseignant : l'état vide, sans tableau" do
    create_teacher(school: create_school)

    sign_in_as @admin
    get school_admin_teachers_path

    assert_response :success
    assert_select "table", 0
    assert_select "main", text: /#{t('empty.title')}/
    assert_select "main", text: /#{t('empty.description')}/
  end

  test "DS-10 : la direction d'un autre établissement ne voit pas ces enseignants" do
    create_teacher(school: @school, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: create_school)
    get school_admin_teachers_path

    assert_response :success
    assert_not_includes response.body, "Gnagbo"
  end

  test "DS-11 : élève, enseignant et équipe reçoivent 403 ; le visiteur va à « Se connecter »" do
    get school_admin_teachers_path
    assert_redirected_to new_session_path

    [ create_student, create_teacher(school: @school), create_team_member ].each do |user|
      sign_in_as user
      get school_admin_teachers_path
      assert_response :forbidden, user.role
      sign_out
    end
  end

  # GD-14 — a teacher of A declared in « 6ème 1 » and « 6ème 2 », author of 3 active assignments and 1 archived one,
  # with students' sessions.
  def seed_teacher_of_a
    @first = create_classroom(school: @school, name: "6ème 1")
    @second = create_classroom(school: @school, name: "6ème 2")
    @teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné", classrooms: [ @first, @second ])
    @active = [ @first, @first, @second ].map { create_assignment(classroom: it, by: @teacher) }
    @archived = create_assignment(classroom: @second, by: @teacher, status: "archived")
    student = create_student(classroom: @first)
    create_exercise_session(student:, status: "completed")
    @teacher
  end

  def td(key, **) = I18n.t("school_admin.teachers.destroy.#{key}", **)
  def refusal(code) = I18n.t("school_admin.shared.errors.#{code}")

  test "GD-14 : établissement actif, chaque ligne a son menu ⋮ « Retirer de l'établissement » et sa modale de confirmation" do
    teacher = seed_teacher_of_a

    sign_in_as @admin
    get school_admin_teachers_path

    assert_select "a[href='#{school_admin_departed_teachers_path}']", text: t("departed")
    id = teacher.public_id
    assert_select "tr#teacher_#{id} td.text-right" do
      assert_select "button[aria-haspopup=menu][aria-controls=teacher-actions-#{id}][aria-label=?]", t("actions", name: "Awa Koné")
      assert_select "#teacher-actions-#{id}[role=menu] button[aria-controls=remove-teacher-#{id}]", text: t("remove")
      assert_select "dialog#remove-teacher-#{id}" do
        assert_select "h2", text: t("remove_title", name: "Awa Koné")
        assert_select "p", text: t("remove_body", first_name: "Awa")
        assert_select "button[type=submit][form=remove-teacher-#{id}-form]", text: t("confirm")
      end
      assert_select "form#remove-teacher-#{id}-form[action='#{school_admin_teacher_path(id)}'] input[name=_method][value=delete]"
    end
  end

  test "GD-14 : le retrait confirmé ; ligne retirée, toast ; classes, élèves, sessions et compte intacts ; audité" do
    teacher = seed_teacher_of_a
    create_teacher(school: @school, last_name: "Collègue")
    teacher_session = open_session.tap { it.post session_path, params: { session: { contact: teacher.contact, pin: "2468" } } }
    counts = -> { [ Orm::Classroom.count, Orm::ClassroomStudent.count, Orm::ExerciseSession.count, Orm::User.count ] }
    before = counts.call

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=remove][target=teacher_#{teacher.public_id}]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(td('detached', name: 'Awa Koné', count: 3))}/
    assert_select "turbo-stream[action=replace][target=school_teachers]", 0
    assert_not Orm::TeacherSchool.exists?(teacher_id: teacher.id)
    assert_not Orm::TeacherClassroom.exists?(teacher_id: teacher.id)
    @active.each(&:reload).each do
      assert_equal [ "archived", @admin.id ], [ it.status, it.archived_by_id ]
      assert_not_nil it.archived_at
    end
    assert_equal [ "archived", teacher.id ], [ @archived.reload.status, @archived.archived_by_id ], "l'archivé le reste"
    assert_equal before, counts.call
    assert_nil teacher.reload.anonymized_at
    departure = Orm::TeacherSchoolDeparture.sole
    assert_equal [ teacher.id, @school.id, @admin.id, nil ], [ departure.teacher_id, departure.school_id, departure.detached_by_id, departure.reinstated_at ]
    event = Orm::AuditEvent.find_by!(action: "teacher.detached")
    assert_equal [ @admin.id, "User", teacher.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "school_id" => @school.id, "classrooms_count" => 2, "assignments_archived" => 3 }, event.metadata)

    teacher_session.get teacher_home_path
    teacher_session.assert_redirected_to pending_account_path
  end

  test "GD-15 : le devoir actif de l'enseignant dans une classe de B reste actif" do
    teacher = seed_teacher_of_a
    elsewhere = create_assignment(classroom: create_classroom(school: create_school), by: teacher)

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :success
    assert_equal "active", elsewhere.reload.status
  end

  test "le dernier enseignant retiré : l'état vide remplace le tableau ; repli HTML : 303 vers la liste, avec la notice" do
    teacher = create_teacher(school: @school, first_name: "Awa", last_name: "Koné")
    other = create_teacher(school: @school, first_name: "Yao", last_name: "Brou")

    sign_in_as @admin
    delete school_admin_teacher_path(other.public_id)
    assert_redirected_to school_admin_teachers_path
    assert_response :see_other
    assert_equal td("detached", name: "Yao Brou", count: 0), flash[:notice]

    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_select "turbo-stream[action=replace][target=school_teachers] template", text: /#{t('empty.title')}/
  end

  test "GD-16 : un enseignant de B : 404, il reste rattaché à B" do
    teacher = create_teacher(school: create_school, last_name: "Ailleurs")

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:not_found)}/

    delete school_admin_teacher_path(teacher.public_id)
    assert_response :not_found
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id)
    assert_not Orm::TeacherSchoolDeparture.exists?
  end

  test "GD-17 : établissement inactif : aucun menu, retrait forgé 403 ; l'équipe reçoit 403" do
    inactive = create_school(status: "inactive")
    teacher = create_teacher(school: inactive, first_name: "Zadi", last_name: "Gnagbo")

    sign_in_as create_school_admin(school: inactive)
    get school_admin_teachers_path
    assert_response :success
    assert_select "tr#teacher_#{teacher.public_id}"
    assert_select "#school_teachers [role=menu], #school_teachers dialog, #school_teachers form", 0
    assert_not_includes response.body, t("remove")

    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:forbidden)}/
    sign_out

    sign_in_as create_team_member
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :forbidden
    assert Orm::TeacherSchool.exists?(teacher_id: teacher.id, school_id: inactive.id)
  end

  test "GD-18 : un enseignant en attente de validation pour A : 404" do
    pending = create_teacher(school: nil, last_name: "Attente")
    create_join_request(school: @school, teacher: pending)

    sign_in_as @admin
    delete school_admin_teacher_path(pending.public_id), as: :turbo_stream

    assert_response :not_found
    assert_not Orm::TeacherSchoolDeparture.exists?
  end

  test "déjà retiré (deux onglets) : 404, toast « Introuvable. »" do
    teacher = create_teacher(school: @school)

    sign_in_as @admin
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream
    assert_response :success
    delete school_admin_teacher_path(teacher.public_id), as: :turbo_stream

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{refusal(:not_found)}/
  end
end
