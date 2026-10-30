require "test_helper"

# prepare-interros-cahier, Lot E (CA-12, CA-15), ADR sujets-de-devoir (ajout du 2026-10-30) : l'enseignant de la classe envoie les exercices
# qu'il a choisis, dans une ou plusieurs leçons, en un devoir. Les identifiants viennent du navigateur : rien n'est cru, rien n'est écrit sur un refus.
class Classroom::AssignmentBatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.local(2026, 10, 5, 10)
    @thales = create_course(name: "Thalès")
    @pythagore = create_course(name: "Pythagore", level: @thales.level, material: @thales.material)
    @classroom = create_classroom(name: "3e 1", level: @thales.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
    @exercises = [ @thales, @thales, @pythagore, @pythagore ].each_with_index.map do |course, index|
      create_exercise(essential: create_essential(course:), title: "Exercice #{index + 1}")
    end
  end

  def tl(key, **) = I18n.t("classroom.assignments.#{key}", **)
  def ids(*exercises) = exercises.map(&:public_id)
  def batch_path(classroom = @classroom) = classroom_assignment_batches_path(classroom.public_id)

  def send_batch(exercise_ids, classroom: @classroom, **)
    post batch_path(classroom), params: { exercise_public_ids: exercise_ids }, as: :turbo_stream, **
  end

  def toast_message = css_select("turbo-stream[action=append][target=toasts] template p").last.text.squish
  def assignments = Orm::ClassroomAssignment.order(:id)

  def assert_nothing_written = assert_equal 0, Orm::ClassroomAssignment.count

  # CA-12
  test "4 exercises of two lessons: 4 active assignments of one same batch, due on the next session day, in Turbo Streams" do
    sign_in_as @teacher

    send_batch(ids(*@exercises))

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    rows = assignments.to_a
    assert_equal @exercises.map(&:id), rows.map(&:assignable_id)
    assert_equal [ [ @classroom.id, "active", @teacher.id, Date.new(2026, 10, 8) ] ],
                 rows.map { [ it.classroom_id, it.status, it.assigned_by_id, it.due_on ] }.uniq
    assert_equal 1, rows.map(&:batch_public_id).uniq.size
    assert_equal 14, rows.first.batch_public_id.length
    # Le bandeau reste en place (ses boutons « Envoyer à » aussi) : seul son compte rendu est remplacé, et il dit au navigateur de vider la sélection.
    assert_select "turbo-stream[action=replace][target=sheet-batch-status]" do
      assert_select "template #sheet-batch-status[data-sent=true][role=status]", text: /#{Regexp.escape(tl("batch.done", classroom: "3e 1", count: 4))}/
    end
    assert_select "turbo-stream[action=replace][target=sheet-batch-bar]", count: 0
    @exercises.each do |exercise|
      target = "assignment_#{@classroom.public_id}_Exercise_#{exercise.public_id}"
      assert_select "turbo-stream[action=replace][target='#{target}'] template ##{target}", text: /#{Regexp.escape(tl("toggle.sheet_assigned", classroom: "3e 1"))}/
    end
  end

  # CA-15
  test "an exercise already assigned is named and skipped, the others are created" do
    create_assignment(classroom: @classroom, assignable: @exercises[1], by: @teacher)
    sign_in_as @teacher

    send_batch(ids(*@exercises.first(3)))

    assert_response :success
    assert_equal [ @exercises[1].id, @exercises[0].id, @exercises[2].id ], assignments.pluck(:assignable_id)
    assert_equal 1, assignments.where.not(batch_public_id: nil).pluck(:batch_public_id).uniq.size
    assert_select "turbo-stream[action=replace][target=sheet-batch-status] template #sheet-batch-status" do |status|
      assert_includes status.text.squish, tl("batch.done", classroom: "3e 1", count: 2)
      assert_includes status.text.squish, tl("batch.already_assigned", titles: "Exercice 2")
    end
  end

  test "all already assigned: nothing created, only the skipped exercises are named" do
    create_assignment(classroom: @classroom, assignable: @exercises[0], by: @teacher)
    sign_in_as @teacher

    send_batch(ids(@exercises[0]))

    assert_response :success
    assert_equal 1, Orm::ClassroomAssignment.count
    assert_select "turbo-stream[action=replace][target=sheet-batch-status] template #sheet-batch-status[data-sent=true]", text: tl("batch.already_assigned", titles: "Exercice 1")
  end

  test "ids sent twice count once" do
    sign_in_as @teacher

    send_batch(ids(@exercises[0], @exercises[1], @exercises[0]))

    assert_response :success
    assert_equal 2, Orm::ClassroomAssignment.count
  end

  test "without Turbo the teacher is sent back to the page with the result" do
    sign_in_as @teacher

    post batch_path, params: { exercise_public_ids: ids(@exercises[0]) }, headers: { "HTTP_REFERER" => course_url(@thales.slug) }

    assert_redirected_to course_url(@thales.slug)
    assert_equal tl("batch.done", classroom: "3e 1", count: 1), flash[:notice]
    assert_equal 1, Orm::ClassroomAssignment.count
  end

  # --- Refus : droits ---------------------------------------------------------------------------------------------------

  test "another teacher's classroom: 403, nothing written" do
    other = create_classroom(level: @thales.level)
    sign_in_as @teacher

    send_batch(ids(@exercises[0]), classroom: other)

    assert_response :forbidden
    assert_nothing_written
  end

  test "a teacher who is not in the classroom at all, a student and the team: 403, nothing written" do
    [ create_teacher(classrooms: [ create_classroom ]), create_student(classroom: @classroom), create_team_member ].each do |user|
      sign_in_as user
      send_batch(ids(@exercises[0]))

      assert_response :forbidden, user.role
      sign_out
    end
    assert_nothing_written
  end

  test "a visitor is sent to sign in, nothing written" do
    post batch_path, params: { exercise_public_ids: ids(@exercises[0]) }

    assert_response :redirect
    assert_nothing_written
  end

  test "an archived classroom: 403, nothing written" do
    archived = create_classroom(status: "archived", level: @thales.level)
    sign_in_as create_teacher(classrooms: [ archived ])

    send_batch(ids(@exercises[0]), classroom: archived)

    assert_response :forbidden
    assert_nothing_written
  end

  test "an unknown classroom: 404" do
    sign_in_as @teacher

    post classroom_assignment_batches_path("inconnue"), params: { exercise_public_ids: ids(@exercises[0]) }, as: :turbo_stream

    assert_response :not_found
    assert_nothing_written
  end

  # --- Refus : la liste envoyée par le navigateur ---------------------------------------------------------------------

  test "no exercise, a scalar or a hash instead of a list: 422 with the count message, nothing written" do
    sign_in_as @teacher

    [ [], nil, @exercises[0].public_id, { "a" => @exercises[0].public_id } ].each do |sent|
      post batch_path, params: { exercise_public_ids: sent }, as: :turbo_stream

      assert_response :unprocessable_entity, sent.inspect
      assert_equal tl("batch.invalid_count"), toast_message
    end
    assert_nothing_written
  end

  test "more than 10 exercises: 422, nothing written; a list of thousands is not even read" do
    sign_in_as @teacher
    many = Array.new(11) { create_exercise(course: @thales).public_id }

    send_batch(many)
    assert_response :unprocessable_entity
    assert_equal tl("batch.invalid_count"), toast_message

    send_batch(Array.new(200) { |n| "id#{n}" })
    assert_response :unprocessable_entity
    # Au-delà des limites de Rack, la requête n'arrive même pas jusqu'à l'application.
    send_batch(Array.new(5_000) { |n| "id#{n}" })
    assert_response :bad_request
    assert_nothing_written
  end

  test "10 exercises are sent" do
    sign_in_as @teacher
    ten = Array.new(10) { create_exercise(course: @thales).public_id }

    send_batch(ten)

    assert_response :success
    assert_equal 10, Orm::ClassroomAssignment.count
  end

  test "an unknown, draft or orphan exercise id: 422, nothing written, even for the valid ones in the list" do
    sign_in_as @teacher
    draft = create_exercise(course: @thales, status: "draft")
    orphan_course = create_course(level: @thales.level, status: "draft")
    orphan = create_exercise(course: orphan_course)

    [ "inconnu", draft.public_id, orphan.public_id ].each do |bad|
      send_batch(ids(@exercises[0]) + [ bad ])

      assert_response :unprocessable_entity, bad
      assert_equal tl("batch.unknown_exercise"), toast_message
    end
    assert_nothing_written
  end

  test "an exercise of another level than the classroom: 422 (other_level), nothing written" do
    sign_in_as @teacher
    elsewhere = create_exercise(course: create_course)

    send_batch(ids(@exercises[0], elsewhere))

    assert_response :unprocessable_entity
    assert_equal tl("refusals.other_level"), toast_message
    assert_nothing_written
  end

  test "a teacher who has not given their session days for the classroom: 422, nothing written" do
    Orm::ClassroomSessionDay.delete_all
    sign_in_as @teacher

    send_batch(ids(@exercises[0]))

    assert_response :unprocessable_entity
    assert_equal tl("batch.needs_session_days"), toast_message
    assert_nothing_written
  end

  test "a refusal leaves the bar alone: the answer carries a toast only, the selection is kept by the browser" do
    sign_in_as @teacher

    send_batch([])

    assert_select "turbo-stream[action=replace]", count: 0
    assert_select "turbo-stream[action=append][target=toasts]", count: 1
  end

  # La page du cours : « Choisir » et le bandeau sont à l'enseignant ; la route le refuse de toute façon aux autres.
  test "the lesson sheet offers « Choisir » and the bar to the teacher of the classroom, not to a student nor to the team" do
    sign_in_as @teacher
    get course_path(@thales.slug)
    assert_select "button[role=checkbox][data-batch-choice='#{@exercises[0].public_id}']", text: tl("batch.choose")
    assert_select "#sheet-batch-bar", count: 1
    assert_select "#sheet-batch-bar button", text: tl("batch.submit", classroom: "3e 1")
    sign_out

    [ create_student(classroom: @classroom), create_team_member ].each do |user|
      sign_in_as user
      get course_path(@thales.slug)

      assert_response :success, user.role
      assert_select "[role=checkbox][data-batch-choice]", count: 0
      assert_select "#sheet-batch-bar", count: 0
      sign_out
    end
  end
end
