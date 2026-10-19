require "test_helper"

# MET-4 (owner, 2026-10-16), ADR-0094 §4.6, UDR-0098 §3.4 and §3.5: one account, one phone number, several schools; the
# current school walls off the whole teacher space. One non-leak test per screen: in A, nothing of B (its name, its
# classrooms, its levels, its exercises to follow, its announcements) is in the page's content. The account panel is
# outside `main`: naming B there is the switcher itself.
class School::CurrentSchoolIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @a = create_school(name: "Lycée moderne d'Abobo")
    @b = create_school(name: "Collège Saint-Michel")
    material = create_material(name: "Mathématiques")
    sixth = create_level(name: "6ème", position: 1)
    fourth = create_level(name: "4ème", position: 3)
    @course6 = create_course(level: sixth, material:, name: "Nombres entiers")
    @course4 = create_course(level: fourth, material:, name: "Puissances de dix")
    @essential4 = create_essential(course: @course4, name: "Écriture scientifique")
    @exercise4 = create_exercise(essential: @essential4, title: "Exercice de Saint-Michel")
    @a6 = create_classroom(school: @a, level: sixth, name: "6ème 1")
    @b4 = create_classroom(school: @b, level: fourth, name: "4ème 2")
    @teacher = create_teacher(school: @a, material:, classrooms: [ @a6, @b4 ], first_name: "Ibrahim", last_name: "Koné")
    add_teacher_school(@teacher, @b)
    @assignment = create_assignment(classroom: @b4, assignable: @exercise4, by: @teacher, due_on: Date.current + 2)
    @mine_in_b = create_message(author: @teacher, audience: "classrooms", classrooms: [ @b4 ], title: "Sortie de Saint-Michel")
    create_message(author: create_school_admin(school: @b), audience: "teachers", school: @b, title: "Réunion de Saint-Michel")
    sign_in_as @teacher
  end

  B_MARKERS = [ "Collège Saint-Michel", "4ème 2", "Puissances de dix", "Exercice de Saint-Michel", "Sortie de Saint-Michel",
                "Réunion de Saint-Michel" ].freeze

  def assert_nothing_of_b(path)
    get path
    assert_response :success, path
    assert_select "main", { count: 1 }, path
    content = css_select("main").text
    B_MARKERS.each { |marker| assert_no_match marker, content, "#{path} : #{marker}" }
    assert_select "main a[href*='#{@b4.public_id}']", { count: 0 }, path
  end

  test "home, classrooms, catalogue, announcements, my announcements, the form, the profile and the invitation: nothing of B" do
    [ teacher_home_path, teacher_classrooms_path, courses_path, announcements_path, my_announcements_path,
      new_announcement_path, profile_path, teacher_invite_path ].each { assert_nothing_of_b(it) }
  end

  # EPM-11 (ADR-0103, réponse du porteur) : les matières de B n'existent pas dans A — ni en-tête, ni accueil, ni catalogue,
  # ni profil ; « Mes matières » ne change que A.
  test "the subjects of B are nowhere in A, and « Mes matières » only changes A" do
    svt = create_material(name: "Sciences de la vie")
    set_teacher_materials(@teacher, @b, [ svt ])
    create_course(level: @a6.level, material: svt, name: "Le vivant")

    [ teacher_home_path, courses_path, profile_path ].each do |path|
      get path
      assert_no_match "Sciences de la vie", response.body, path
      assert_no_match "Le vivant", response.body, path
    end

    english = create_material(name: "Anglais")
    patch profile_materials_path, params: { profile_materials: { material_slugs: [ english.slug ] } }

    assert_equal [ english.id ], Orm::TeacherSchoolMaterial.where(teacher: @teacher, school: @a).pluck(:material_id)
    assert_equal [ svt.id ], Orm::TeacherSchoolMaterial.where(teacher: @teacher, school: @b).pluck(:material_id),
                 "la liste de B garde sa propre matière"
    [ teacher_home_path, courses_path ].each do |path|
      get path
      assert_no_match "Sciences de la vie", response.body, path
    end
  end

  test "a course and an exercise of a level taught only in B offer no classroom of B to assign" do
    assert_nothing_of_b(course_path(@course6.slug))
    get exercise_path(@exercise4.public_id)
    assert_response :success
    assert_select "main", text: /4ème 2/, count: 0
    assert_select "main a[href*='#{@b4.public_id}'], main form[action*='#{@b4.public_id}']", count: 0
  end

  # A level taught in both schools: its course and its essential name nothing of B.
  test "a course and an essential of a level taught in A and in B: nothing of B" do
    create_classroom(school: @a, level: @b4.level, name: "4ème 5").tap { Orm::TeacherClassroom.create!(teacher: @teacher, classroom: it) }

    [ course_path(@course4.slug), course_essential_path(@course4.slug, @essential4.slug) ].each do |path|
      get path
      assert_response :success, path
      assert_select "main", { count: 1 }, path
      assert_no_match "4ème 2", css_select("main").text, path
      assert_no_match "Collège Saint-Michel", css_select("main").text, path
      assert_select "main a[href*='#{@b4.public_id}'], main form[action*='#{@b4.public_id}']", { count: 0 }, path
    end
  end

  # ADR-0094 §10 : trois annonces en ligne dans B ; depuis A, le formulaire (« celle-ci partira ») et « Mes annonces »
  # n'en nomment aucune.
  test "three live announcements in B: the form and « Mes annonces » in A name none of them" do
    titles = [ "Cantine de Saint-Michel", "Chorale de Saint-Michel" ]
    titles.each { create_message(author: @teacher, audience: "classrooms", classrooms: [ @b4 ], title: it) }

    [ new_announcement_path, my_announcements_path ].each do |path|
      get path
      assert_response :success, path
      [ *titles, "Sortie de Saint-Michel" ].each { assert_no_match it, css_select("main").text, "#{path} : #{it}" }
    end
  end

  test "a classroom of B, its exercise to follow and its announcement are refused from A, and nothing is written" do
    [ classroom_path(@b4.public_id), classroom_assignment_path(@b4.public_id, @assignment.public_id),
      new_classroom_assignment_path(@b4.public_id) ].each do |path|
      get path
      assert_redirected_to teacher_home_path, path
      assert_equal I18n.t("errors.codes.other_school"), flash[:alert]
    end

    get edit_announcement_path(@mine_in_b.public_id)
    assert_response :not_found
    patch archive_assignment_path(@assignment.public_id), params: { classroom_public_id: @b4.public_id }
    assert_redirected_to teacher_home_path
    assert_equal "active", @assignment.reload.status
  end

  test "back in B, the teacher finds B whole, and nothing of A" do
    patch teacher_current_school_path, params: { school_public_id: @b.public_id }
    get teacher_home_path

    assert_select "main", text: /4ème 2/
    assert_select "main", text: /6ème 1/, count: 0
    get my_announcements_path
    assert_select "main", text: /Sortie de Saint-Michel/
    get classroom_path(@b4.public_id)
    assert_response :success
  end
end
