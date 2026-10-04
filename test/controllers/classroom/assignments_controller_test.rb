require "test_helper"

# CL-16, CL-17, CL-20, AS-18, AS-19, ADR-0048, UDR-0028: the teacher of a classroom assigns an exercise — the only
# assignable resource since ADR-0072 §4.1 — and withdraws it. Every answer is a Turbo Stream that replaces the toggle — the old application answered
# 204 and left the button unchanged, raised RecordNotUnique on reassignment and wrote a teacher profile id as the author.
class Classroom::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course = create_course(name: "Génétique")
    # UDR-0013, amendement du 2026-10-01 : la classe est du niveau du cours, seul assignable.
    @classroom = create_classroom(name: "6ème 1", level: @course.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @essential = create_essential(course: @course, name: "La méiose")
    @exercise = create_exercise(essential: @essential, title: "Méiose")
  end

  def tl(key, **) = I18n.t("classroom.assignments.#{key}", **)
  def including(text) = /#{Regexp.escape(text)}/
  def toggle_id(type, key, classroom: @classroom) = "assignment_#{classroom.public_id}_#{type}_#{key}"

  def assign(type, key, classroom: @classroom, **)
    post classroom_assignments_path(classroom.public_id), params: { assignment: { assignable_type: type, assignable_key: key } }, **
  end

  # La modale des jours envoie toujours le champ caché vide, puis les cases cochées ; « Plus tard » ajoute later.
  def assign_with_days(weekdays, key: @exercise.public_id, later: false, **)
    params = { assignment: { assignable_type: "Exercise", assignable_key: key, weekdays: [ "", *weekdays ] } }
    params[:later] = "1" if later
    post classroom_assignments_path(@classroom.public_id), params:, **
  end

  def session_days(teacher = @teacher) = Orm::ClassroomSessionDay.where(teacher_id: teacher.id).order(:weekday).pluck(:weekday)

  def withdraw(assignment, classroom: @classroom, **)
    patch archive_assignment_path(assignment.public_id), params: { classroom_public_id: classroom.public_id }, **
  end

  test "an exercise is assigned then withdrawn, in Turbo Streams that replace the toggle" do
    sign_in_as @teacher
    type = "Exercise"
    key = @exercise.public_id

    assign(type, key, as: :turbo_stream)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assignment = Orm::ClassroomAssignment.find_by!(assignable_type: type, assignable_id: @exercise.id)
    assert_equal [ @classroom.id, "active", @teacher.id ], [ assignment.classroom_id, assignment.status, assignment.assigned_by_id ]
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.done", name: "Méiose", classroom: "6ème 1"))
    assert_select "turbo-stream[action=replace][target='#{toggle_id(type, key)}']" do
      assert_select "template ##{toggle_id(type, key)}", text: including(tl("toggle.assigned"))
      assert_select "form[action='#{archive_assignment_path(assignment.public_id)}'] input[name=classroom_public_id][value='#{@classroom.public_id}']"
    end

    withdraw(assignment, as: :turbo_stream)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal [ "archived", @teacher.id ], assignment.reload.values_at(:status, :archived_by_id)
    assert_not_nil assignment.archived_at
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("archive.done", name: "Méiose", classroom: "6ème 1"))
    # Sans jours de séance, « Assigner » rouvre la modale des jours (UDR-0062 §3.4), sans attendre un rechargement.
    assert_select "turbo-stream[action=replace][target='#{toggle_id(type, key)}'] template" do
      assert_select "a[href='#{new_classroom_assignment_path(@classroom.public_id, assignable_key: key)}'][data-turbo-frame=modal]"
      assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}']", 0
    end
  end

  test "withdrawn by a teacher who gave their session days, the toggle assigns again in one click" do
    Orm::ClassroomSessionDay.create!(teacher_id: @teacher.id, classroom_id: @classroom.id, weekday: 1)
    assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher)
    sign_in_as @teacher

    withdraw(assignment, as: :turbo_stream)

    assert_response :success
    assert_select "turbo-stream[action=replace][target='#{toggle_id("Exercise", @exercise.public_id)}'] template" do
      assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}']" do
        assert_select "input[name='assignment[assignable_type]'][value=Exercise]"
        assert_select "input[name='assignment[assignable_key]'][value='#{@exercise.public_id}']"
      end
      assert_select "a[data-turbo-frame=modal]", 0
    end
  end

  # ADR-0072 §4.1 : un cours ou une fiche ne s'assigne plus ; le type est refusé en place, comme un type inconnu.
  test "a course or an essential sheet is refused in place (422, invalid) and nothing is written" do
    sign_in_as @teacher

    [ [ "Course", @course.slug ], [ "Essential", @essential.slug ] ].each do |type, key|
      assign(type, key, as: :turbo_stream)

      assert_response :unprocessable_entity, type
      assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.invalid"))
      assert_select "turbo-stream[action=replace]", 0
    end
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "posting the same assignment again says it is already assigned (422) and writes nothing" do
    sign_in_as @teacher
    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_no_difference -> { Orm::ClassroomAssignment.count } do
      assign("Exercise", @exercise.public_id, as: :turbo_stream)
    end
    assert_response :unprocessable_entity
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.already_assigned"))
    assert_select "turbo-stream[action=replace]", 0
  end

  test "reassigning after a withdrawal creates a new active row, without a uniqueness error" do
    first = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, status: "archived")
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_response :success
    assert_equal [ "archived", "active" ], Orm::ClassroomAssignment.order(:id).pluck(:status)
    assert_equal "archived", first.reload.status
  end

  test "withdrawing an assignment already withdrawn says so (422) and writes nothing" do
    archived = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, status: "archived")
    sign_in_as @teacher

    assert_no_changes -> { archived.reload.updated_at } do
      withdraw(archived, as: :turbo_stream)
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.already_archived"))
  end

  test "an unknown resource type is refused in place (422)" do
    sign_in_as @teacher

    assign("ExamSubject", "sujet", as: :turbo_stream)

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.invalid"))
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "an unpublished resource, or an unknown one, is not found (404, in a stream)" do
    draft = create_exercise(essential: @essential, status: "draft")
    sign_in_as @teacher

    [ draft.public_id, "inconnu" ].each do |key|
      assign("Exercise", key, as: :turbo_stream)

      assert_response :not_found
      assert_equal "text/vnd.turbo-stream.html", response.media_type
    end
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "another teacher's classroom: 403 on both actions, and nothing is written" do
    other = create_classroom
    foreign = create_assignment(classroom: other, assignable: @exercise)
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, classroom: other, as: :turbo_stream)
    assert_response :forbidden
    withdraw(foreign, classroom: other, as: :turbo_stream)
    assert_response :forbidden

    assert_equal [ "active" ], Orm::ClassroomAssignment.pluck(:status)
  end

  test "an assignment of another classroom cannot be withdrawn through one's own classroom (404)" do
    foreign = create_assignment(classroom: create_classroom, assignable: @exercise)
    sign_in_as @teacher

    withdraw(foreign, as: :turbo_stream)

    assert_response :not_found
    assert_equal "active", foreign.reload.status
  end

  test "an archived classroom accepts no assignment (403)" do
    archived = create_classroom(status: "archived")
    teacher = create_teacher(classrooms: [ archived ])
    sign_in_as teacher

    assign("Exercise", @exercise.public_id, classroom: archived, as: :turbo_stream)

    assert_response :forbidden
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "a student receives 403 and writes nothing; the team may assign" do
    sign_in_as create_student(classroom: @classroom)
    assign("Exercise", @exercise.public_id, as: :turbo_stream)
    assert_response :forbidden
    assert_equal 0, Orm::ClassroomAssignment.count
    sign_out

    member = create_team_member
    sign_in_as member
    assign("Exercise", @exercise.public_id, as: :turbo_stream)
    assert_response :success
    assert_equal [ member.id ], Orm::ClassroomAssignment.pluck(:assigned_by_id)
  end

  test "a visitor is sent to the sign-in page" do
    assign("Exercise", @exercise.public_id)

    assert_redirected_to new_session_path
  end

  test "without Turbo, every answer leads back to where the button was, with a flash" do
    origin = classroom_essential_url(@classroom.public_id, @course.slug, @essential.slug)
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, headers: { "HTTP_REFERER" => origin })
    assert_redirected_to origin
    assert_equal tl("create.done", name: "Méiose", classroom: "6ème 1"), flash[:notice]

    assign("Exercise", @exercise.public_id, headers: { "HTTP_REFERER" => origin })
    assert_redirected_to origin
    assert_equal tl("refusals.already_assigned"), flash[:alert]

    withdraw(Orm::ClassroomAssignment.sole)
    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal tl("archive.done", name: "Méiose", classroom: "6ème 1"), flash[:notice]

    withdraw(Orm::ClassroomAssignment.sole)
    assert_redirected_to classroom_path(@classroom.public_id)
    assert_equal tl("refusals.already_archived"), flash[:alert]
  end

  # UDR-0013, amendement du 2026-10-01 : un contenu d'un autre niveau ne s'assigne pas ; le refus dit pourquoi.
  test "an exercise of another level is refused in 422 with its reason, and nothing is written" do
    other = create_exercise(essential: create_essential(course: create_course(name: "Mécanique")))
    sign_in_as @teacher

    assign("Exercise", other.public_id, as: :turbo_stream)

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.other_level"))
    assert_not Orm::ClassroomAssignment.exists?
  end

  # RE-25 — UDR-0069 §3.8 : le catalogue ne propose que les classes du niveau et de la série du cours ; un POST forgé vers
  # une autre classe de l'enseignant est refusé par la règle existante, en place, et rien n'est écrit.
  test "a forged POST of a Tle D exercise to the teacher's 3ème 1 or Tle C 1: 422 other_level, nothing written" do
    tle = create_level(name: "Tle")
    tle_d = create_exercise(essential: create_essential(course: create_course(level: tle, series: create_series(name: "D"))))
    third = create_classroom(name: "3ème 1", level: create_level(name: "3ème"))
    tle_c = create_classroom(name: "Tle C 1", level: tle, series: create_series(name: "C"))
    sign_in_as create_teacher(classrooms: [ third, tle_c ])

    [ third, tle_c ].each do |classroom|
      assign("Exercise", tle_d.public_id, classroom:, as: :turbo_stream)

      assert_response :unprocessable_entity, classroom.name
      assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("refusals.other_level"))
      assert_select "turbo-stream[action=replace]", 0
    end
    assert_not Orm::ClassroomAssignment.exists?
  end

  # UDR-0069 §3.8 : sur une page qui porte les bascules de plusieurs classes, chaque libellé nomme la classe.
  test "the streams' toggles name the classroom in their aria-labels" do
    Orm::ClassroomSessionDay.create!(teacher_id: @teacher.id, classroom_id: @classroom.id, weekday: 1)
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assignment = Orm::ClassroomAssignment.sole
    assert_select "turbo-stream[action=replace][target='#{toggle_id('Exercise', @exercise.public_id)}'] template " \
                  "form[action='#{archive_assignment_path(assignment.public_id)}'] button[aria-label=?]",
                  tl("toggle.archive_from_label", name: "Méiose", classroom: "6ème 1")

    withdraw(assignment, as: :turbo_stream)

    assert_select "turbo-stream[action=replace][target='#{toggle_id('Exercise', @exercise.public_id)}'] template " \
                  "form[action='#{classroom_assignments_path(@classroom.public_id)}'] button[aria-label=?]",
                  tl("toggle.assign_to_label", name: "Méiose", classroom: "6ème 1")
    assert_equal "Assigner « Méiose » à 6ème 1", tl("toggle.assign_to_label", name: "Méiose", classroom: "6ème 1")
    assert_equal "Retirer « Méiose » de 6ème 1", tl("toggle.archive_from_label", name: "Méiose", classroom: "6ème 1")
  end

  # UDR-0062 §3.4 : la modale « Quels jours voyez-vous la <classe> ? », servie dans le frame « modal », lisible sans JavaScript.
  test "the days modal names the classroom and the exercise, with six weekdays, « Plus tard » and « Assigner »" do
    sign_in_as @teacher

    get new_classroom_assignment_path(@classroom.public_id, assignable_key: @exercise.public_id)

    assert_response :success
    assert_select "turbo-frame#modal dialog[open]" do
      assert_select "h2", text: tl("new.title", classroom: "6ème 1")
      assert_select "p", text: including(tl("new.context", name: "Méiose"))
      assert_select "form[action='#{classroom_assignments_path(@classroom.public_id)}'][method=post]" do
        assert_select "input[type=hidden][name='assignment[assignable_type]'][value=Exercise]"
        assert_select "input[type=hidden][name='assignment[assignable_key]'][value='#{@exercise.public_id}']"
        assert_select "fieldset legend", text: tl("new.legend")
        assert_select "input[type=checkbox][name='assignment[weekdays][]']", 6
        assert_equal %w[1 2 3 4 5 6], css_select("input[type=checkbox]").map { it["value"] }
        assert_equal [ "Lun.", "Mar.", "Mer.", "Jeu.", "Ven.", "Sam." ], css_select("fieldset label span[aria-hidden]").map(&:text)
      end
    end
    assert_select "button[type=submit][name=later]", text: tl("new.later")
    assert_select "button[type=submit]:not([name])", text: including(tl("new.submit"))
  end

  test "the days modal: 404 for an unknown or unpublished exercise, 403 for the team, another teacher or an archived classroom" do
    draft = create_exercise(essential: @essential, status: "draft")
    sign_in_as @teacher
    [ draft.public_id, "inconnu" ].each do |key|
      get new_classroom_assignment_path(@classroom.public_id, assignable_key: key)
      assert_response :not_found
    end
    sign_out

    archived = create_classroom(status: "archived", level: @course.level)
    [ [ create_team_member, @classroom ], [ create_teacher, @classroom ], [ create_teacher(classrooms: [ archived ]), archived ] ].each do |user, classroom|
      sign_in_as user
      get new_classroom_assignment_path(classroom.public_id, assignable_key: @exercise.public_id)
      assert_response :forbidden
      sign_out
    end
  end

  test "Monday 5 October, Monday and Thursday checked: days saved, due Thursday 8, toast with the date, page refreshed" do
    travel_to Time.zone.local(2026, 10, 5, 10)
    sign_in_as @teacher

    assign_with_days(%w[1 4], as: :turbo_stream)

    assert_response :success
    assignment = Orm::ClassroomAssignment.sole
    assert_equal Date.new(2026, 10, 8), assignment.due_on
    assert_equal [ 1, 4 ], session_days
    assert_select "turbo-stream[action=append][target=toasts]",
                  text: including(tl("create.done_due", name: "Méiose", classroom: "6ème 1", date: "jeudi 8 oct."))
    assert_select "turbo-stream[action=replace][target='#{toggle_id('Exercise', @exercise.public_id)}'] template",
                  text: including("Pour jeu. 8 oct.")
    assert_select "turbo-stream[action=refresh]"
  end

  test "once the days are known, one click assigns with the due date; no refresh" do
    travel_to Time.zone.local(2026, 10, 8, 10)
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id,
                                                                weekdays: [ 1, 4 ], at: Time.current)
    sign_in_as @teacher

    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_response :success
    assert_equal Date.new(2026, 10, 12), Orm::ClassroomAssignment.sole.due_on
    assert_select "turbo-stream[action=refresh]", 0
  end

  test "« Plus tard »: assigned without due date, no day written, the toast has no date" do
    sign_in_as @teacher

    assign_with_days(%w[1 4], later: true, as: :turbo_stream)

    assert_response :success
    assert_nil Orm::ClassroomAssignment.sole.due_on
    assert_empty session_days
    assert_select "turbo-stream[action=append][target=toasts]", text: including(tl("create.done", name: "Méiose", classroom: "6ème 1"))
    assert_select "turbo-stream[action=refresh]", 0
  end

  test "« Assigner » without any day: 422, the modal again with its error on the fieldset, nothing written" do
    sign_in_as @teacher

    assign_with_days([], as: :turbo_stream)

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog[open]"
    assert_select "fieldset[aria-invalid=true][aria-describedby=assignment_weekdays_error]"
    assert_select "#assignment_weekdays_error", text: including(tl("new.weekdays_blank"))
    assert_equal 0, Orm::ClassroomAssignment.count
    assert_empty session_days
  end

  test "the days modal answered for an unknown exercise or classroom: 404, nothing written" do
    sign_in_as @teacher

    assign_with_days([], key: "inconnu", as: :turbo_stream)
    assert_response :not_found

    get new_classroom_assignment_path("inconnue", assignable_key: @exercise.public_id)
    assert_response :not_found
    assert_equal 0, Orm::ClassroomAssignment.count
  end

  test "the team assigns without due date; days sent by the team: forbidden, nothing written" do
    sign_in_as create_team_member

    assign_with_days(%w[1 4], as: :turbo_stream)
    assert_response :forbidden
    assert_equal 0, Orm::ClassroomAssignment.count
    assert_equal 0, Orm::ClassroomSessionDay.count

    assign("Exercise", @exercise.public_id, as: :turbo_stream)
    assert_response :success
    assert_nil Orm::ClassroomAssignment.sole.due_on
  end

  test "two teachers: the due date follows the author's days" do
    travel_to Time.zone.local(2026, 10, 5, 10)
    colleague = create_teacher(classrooms: [ @classroom ])
    repository = Repositories::Classroom::SessionDaysRepository.new
    repository.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ], at: Time.current)
    repository.replace(teacher_id: colleague.id, classroom_id: @classroom.id, weekdays: [ 2 ], at: Time.current)
    sign_in_as colleague

    assign("Exercise", @exercise.public_id, as: :turbo_stream)

    assert_equal Date.new(2026, 10, 6), Orm::ClassroomAssignment.sole.due_on
  end

  test "without JavaScript, the days form leads back to the page the modal was opened from" do
    origin = classroom_essential_url(@classroom.public_id, @course.slug, @essential.slug)
    sign_in_as @teacher

    get new_classroom_assignment_path(@classroom.public_id, assignable_key: @exercise.public_id), headers: { "HTTP_REFERER" => origin }
    assert_select "input[type=hidden][name=return_to][value='#{origin}']"

    post classroom_assignments_path(@classroom.public_id),
         params: { assignment: { assignable_type: "Exercise", assignable_key: @exercise.public_id, weekdays: [ "", "2" ] }, return_to: origin }
    assert_redirected_to origin
    assert_equal [ 2 ], session_days

    post classroom_assignments_path(@classroom.public_id),
         params: { assignment: { assignable_type: "Exercise", assignable_key: create_exercise(essential: @essential).public_id },
                   return_to: "https://ailleurs.example/piege" }
    assert_redirected_to classroom_path(@classroom.public_id)
  end
end
