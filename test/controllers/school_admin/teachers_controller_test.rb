require "test_helper"

# ADR-0065, UDR-0052 (DS-06, DS-10, DS-11): « Enseignants », read by the direction on its own school only.
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
      assert_select "th[scope=col]", 3
      assert_select "tbody tr", 2
      assert_select "tr#teacher_0 th[scope=row]", text: "Yao Brou"
      assert_select "tr#teacher_0 td", text: t("no_classroom")
      assert_select "tr#teacher_1 th[scope=row]", text: "Awa Koné"
      assert_select "tr#teacher_1 td", text: "Mathématiques"
      assert_select "tr#teacher_1 td", text: "2nde C 1, Tle D 2"
    end
    [ "Anonyme", "Attente", "Ailleurs", "1ère A 3", awa.public_id, idle.public_id ].each do |absent|
      assert_not_includes response.body, absent
    end
    Orm::User.where(role: "teacher").pluck(:contact).compact.each { assert_not_includes response.body, it }
    assert_select "form, button[type=submit]", 0
  end

  test "un enseignant sans matière connue : « — » lu « non calculé »" do
    teacher = create_user(role: "teacher", first_name: "Awa", last_name: "Koné")
    Orm::TeacherSchool.create!(teacher:, school: @school, primary: true)

    sign_in_as @admin
    get school_admin_teachers_path

    assert_select "tr#teacher_0 td span[aria-hidden=true]", text: "—"
    assert_select "tr#teacher_0 td span.sr-only", text: t("missing")
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
end
