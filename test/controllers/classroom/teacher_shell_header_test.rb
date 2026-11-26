require "test_helper"

# accueil-enseignant-actions (UDR §3.4, CA-6) : l'enseignant n'a la barre du haut (en-tête du shell) que sur son accueil ;
# chaque autre page commence par un retour (les modales servies en page, « Annuler » compris, ne sont pas des pages). Direction et élève gardent leur en-tête.
class Classroom::TeacherShellHeaderTest < ActionDispatch::IntegrationTest
  SHELL_HEADER = "header.sticky.h-bar"
  BACK = "nav[aria-label='#{I18n.t('components.back_link.label')}'] a".freeze

  setup do
    @school = create_school
    @svt = create_material(name: "SVT", category: "science")
    @classroom = create_classroom(school: @school, level: create_level(name: "Tle"), name: "Tle D 1")
    @teacher = create_teacher(school: @school, material: @svt, classrooms: [ @classroom ])
    @student = create_student(classroom: @classroom)
    @assignment = create_assignment(classroom: @classroom, by: @teacher,
                                    assignable: create_exercise(essential: create_essential(course: @course = create_course(material: @svt))))
  end

  test "CA-6: the teacher home keeps the shell header" do
    sign_in_as @teacher

    get teacher_home_path

    assert_select SHELL_HEADER, 1
    assert_select "aside.top-bar"
  end

  test "CA-6: every other teacher page has neither the shell header nor its offset, and starts with a way back" do
    pilot_flags!(teacher_announcements_enabled: true)
    sign_in_as @teacher

    [ classroom_path(@classroom.public_id), classroom_student_path(@classroom.public_id, @student.public_id),
      classroom_assignment_path(@classroom.public_id, @assignment.public_id), teacher_classrooms_path, courses_path,
      announcements_path, my_announcements_path, profile_path, profile_materials_path, teacher_schools_path, teacher_menu_path,
      teacher_invite_path, course_path(@course.slug) ].each do |path|
      get path

      assert_response :success, path
      assert_select SHELL_HEADER, { count: 0 }, "#{path} garde la barre du haut"
      assert_select "aside.top-0", { count: 1 }, "#{path} : la barre latérale reste, depuis le haut"
      assert_select "main #{BACK}", { minimum: 1 }, "#{path} n'a pas de retour"
    end
  end

  test "CA-6: the direction and the student keep their shell header" do
    [ create_school_admin(school: @school), @student ].each do |actor|
      sign_in_as actor

      get home_path_for_test(actor)

      assert_select SHELL_HEADER, 1
    end
  end

  private

  def home_path_for_test(actor) = actor.role == "student" ? student_home_path : school_admin_teachers_path
end
