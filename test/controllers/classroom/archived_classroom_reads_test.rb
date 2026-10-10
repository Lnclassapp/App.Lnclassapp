require "test_helper"

# ADR-0088 (archivage d'une classe), Lot C : ce que voient les élèves et les enseignants d'une classe archivée. L'archivage ne touche
# ni les adhésions ni les assignations : ce sont les lectures qui font disparaître la classe, et la restauration la rend à l'identique.
class Classroom::ArchivedClassroomReadsTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @course = create_course(name: "Génétique")
    @level = @course.level
    @classroom = create_classroom(school: @school, level: @level, name: "Tle D 1")
    @exercise = create_exercise(essential: create_essential(course: @course, name: "La méiose"), title: "Méiose, les étapes")
    @teacher = create_teacher(school: @school, material: @course.material, classrooms: [ @classroom ])
    @student = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi")
    @assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, due_on: Date.current + 2,
                                    assigned_at: 1.day.ago)
  end

  def repository = Repositories::Classroom::ClassroomRepository.new
  def archive!(classroom = @classroom) = repository.archive(id: classroom.id, at: Time.current)
  def restore!(classroom = @classroom) = repository.restore(id: classroom.id, at: Time.current)
  def tl(key, **) = I18n.t("classroom.#{key}", **)

  test "the student whose only classroom is archived sees « Choisis ta classe », no exercise and no classroom name" do
    sign_in_as @student
    get student_home_path
    assert_select "#student_home_classroom", text: /Tle D 1/
    assert_select "#student_home_exercises"

    archive!
    get student_home_path

    assert_response :success
    assert_select "#student_home_no_classroom", text: /#{Regexp.escape(tl("student_homes.no_classroom.title"))}/
    assert_select "#student_home_classroom, #student_home_exercises", 0
    assert_no_match "Tle D 1", response.body
    assert_no_match "Méiose, les étapes", response.body
    assert_equal [ true, nil ], [ Orm::ClassroomStudent.exists?(student: @student, left_at: nil), Queries::Classroom::StudentClassroomQuery.new.call(student_id: @student.id) ]
  end

  test "the student of two classrooms, one archived, keeps the other and its name in the header" do
    other = create_classroom(school: @school, level: @level, name: "Tle D 2")
    Orm::ClassroomStudent.where(student: @student).update_all(primary: false)
    Orm::ClassroomStudent.create!(classroom: other, student: @student, primary: true, joined_at: Time.current, joined_via: "standard")
    sign_in_as @student

    archive!
    get student_home_path

    assert_response :success
    assert_select "#student_home_classroom", text: /Tle D 2/
    assert_no_match "Tle D 1", response.body
    assert_equal "Tle D 2 · Lycée Classique d'Abidjan", Queries::Identity::ShellUserQuery.new.call(user_id: @student.id).detail
  end

  test "the teacher no longer sees the archived classroom, nor its deadlines, and can no longer assign to it" do
    sign_in_as @teacher
    get teacher_home_path
    assert_match "Tle D 1", response.body
    assert_match "Méiose, les étapes", response.body

    archive!
    get teacher_home_path

    assert_response :success
    assert_no_match "Tle D 1", response.body
    assert_no_match "Méiose, les étapes", response.body
    assert_empty Queries::Classroom::TeacherFollowUpsQuery.new.call(teacher_id: @teacher.id)
    selection = Queries::Classroom::TeachingSelectionQuery.new.call(school_id: @school.id, teacher_id: @teacher.id)
    assert_empty selection.levels.flat_map { |level| level.classrooms.map(&:name) }
    assert_no_difference -> { Orm::ClassroomAssignment.count } do
      post classroom_assignments_path(@classroom.public_id),
           params: { assignment: { assignable_type: "Exercise", assignable_key: create_exercise(essential: @exercise.essential).public_id } },
           as: :turbo_stream
    end
    assert_not_equal 200, response.status

    restore!
    get teacher_home_path
    assert_match "Tle D 1", response.body
  end

  test "the link of an archived classroom refuses the student with a message about archiving, and works again once restored" do
    token = @classroom.reload.link_token
    free = create_student
    sign_in_as free

    archive!
    get join_classroom_path(token)
    assert_response :success
    assert_select "#classroom-archived[role=alert]", text: /#{Regexp.escape(tl("joins.classroom_preview.archived"))}/

    # TROU CONNU (hors Lot C) : JoinAsStudent traite le lien archivé comme inconnu (classroom_designation.rb:25), donc 404 sans
    # message, et joins/new.html.erb offre encore le bouton. Ce test caractérise l'état actuel : aucune adhésion n'est créée.
    post join_classroom_path(token)
    assert_response :not_found
    assert_equal 0, Orm::ClassroomStudent.where(student: free).count

    restore!
    get join_classroom_path(token)
    assert_response :success
    assert_select "#classroom-archived", 0
    assert_select "#join-form"
    assert_equal token, @classroom.reload.link_token
  end

  test "the visitor opening the link of an archived classroom is told it is archived" do
    archive!

    get join_classroom_path(@classroom.link_token)

    assert_response :success
    assert_select "#classroom-archived", text: /#{Regexp.escape(tl("joins.classroom_preview.archived"))}/
  end
end
