require "test_helper"

# ME-17 to ME-20 (ADR-0094 §4.6, UDR-0100 §3.1): M. Koné teaches in A and in B. On every screen of the direction of A
# (home, a level, a classroom, the activity, « Enseignants », the « Retirer » confirmation, « Enseignants retirés »,
# « Établissement »), nothing of B: neither its name, nor its classroom, nor his assignment or announcement there.
# One non-leak test per screen; then A withdraws him, and B sees nothing change.
class SchoolAdmin::SharedTeacherIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @a = create_school(name: "Lycée moderne d'Abobo")
    @b = create_school(name: "Collège Saint-Michel")
    third = create_level(name: "3ème", position: 4)
    fourth = create_level(name: "4ème", position: 3)
    @a3 = create_classroom(school: @a, level: third, name: "3ème 1")
    @b4 = create_classroom(school: @b, level: fourth, name: "4ème 2")
    create_classroom(school: @a, level: fourth, name: "4ème 5")
    @kone = create_teacher(school: @a, classrooms: [ @a3, @b4 ], first_name: "Ibrahim", last_name: "Koné")
    add_teacher_school(@kone, @b)
    exercise = create_exercise(title: "Exercice de Saint-Michel")
    create_assignment(classroom: @b4, assignable: exercise, by: @kone, due_on: Date.current + 2)
    create_message(author: @kone, audience: "classrooms", classrooms: [ @b4 ], title: "Sortie de Saint-Michel")
    @direction_a = create_school_admin(school: @a)
    @direction_b = create_school_admin(school: @b)
  end

  B_MARKERS = [ "Collège Saint-Michel", "4ème 2", "Exercice de Saint-Michel", "Sortie de Saint-Michel" ].freeze

  def assert_nothing_of_b(path)
    get path
    assert_response :success, path
    B_MARKERS.each { |marker| assert_no_match marker, response.body, "#{path} : #{marker}" }
    assert_no_match @b4.public_id, response.body, path
  end

  test "ME-17 to ME-19: no screen of the direction of A shows anything of B" do
    sign_in_as @direction_a

    [ school_admin_classrooms_path, school_admin_level_path(@a3.level.slug), school_admin_level_path("4eme"),
      school_admin_classroom_path(@a3.public_id), school_admin_activity_path, school_admin_teachers_path,
      school_admin_teacher_removal_path(@kone.public_id), school_admin_departed_teachers_path, school_admin_school_path ]
      .each { assert_nothing_of_b(it) }
    get school_admin_teachers_path
    assert_select "main", text: /Ibrahim Koné.*3ème 1/m
  end

  test "ME-17: the direction of B sees M. Koné with « 4ème 2 » only" do
    sign_in_as @direction_b
    get school_admin_teachers_path

    assert_select "main", text: /Ibrahim Koné.*4ème 2/m
    assert_no_match "3ème 1", css_select("main").text
    assert_no_match "Lycée moderne d", css_select("main").text
  end

  test "ME-20: the direction of A withdraws him: he stays in B, now primary, not on the waiting screen; B sees no change" do
    sign_in_as @direction_a
    delete school_admin_teacher_path(@kone.public_id)
    sign_out

    assert_equal [ [ @b.id, true ] ], Orm::TeacherSchool.where(teacher: @kone).pluck(:school_id, :primary)
    sign_in_as @kone
    get teacher_home_path
    assert_response :success
    assert_select "main", text: /4ème 2/
    sign_out
    sign_in_as @direction_b
    get school_admin_teachers_path
    assert_select "main", text: /Ibrahim Koné.*4ème 2/m
  end
end
