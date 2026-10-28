require "test_helper"

# CA-29 à CA-31, CA-33, CA-34 (ADR-0115, PRD §3 « La pause ») : après 3 copies vérifiées d'affilée sur un exercice,
# « Recommencer » est refusé jusqu'à l'heure de reprise, par un POST direct comme depuis la page de l'exercice.
class Assessment::ExerciseSessionsPauseTest < ActionDispatch::IntegrationTest
  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2)
    course = @exercise.essential.course
    classroom = create_classroom(level: course.level, series: course.series)
    @student = create_student(classroom:)
    @at = Time.zone.local(2026, 10, 28, 10, 0)
  end

  def pause_message = I18n.t("assessment.exercises.show.paused", time: "10 h 50")

  def complete_copies(*minutes, exercise: @exercise)
    minutes.each do |minute|
      create_exercise_session(student: @student, exercise:, status: "completed", completed_at: @at + minute.minutes)
    end
  end

  test "CA-29 : un POST à 10 h 49 après 3 copies d'affilée ne crée rien et renvoie à l'exercice avec l'heure de reprise" do
    complete_copies(0, 10, 20)
    sign_in_as @student

    travel_to @at + 49.minutes do
      assert_no_difference -> { Orm::ExerciseSession.count } do
        post exercise_sessions_path(@exercise.public_id)
      end
      assert_redirected_to exercise_path(@exercise.public_id)
      follow_redirect!
    end

    assert_nil flash[:alert]
    assert_select "#exercise_paused", count: 1, text: pause_message
  end

  test "CA-29 : Recommencer pendant la pause laisse la copie ouverte en place" do
    complete_copies(0, 10, 20)
    open = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    travel_to @at + 49.minutes do
      post exercise_sessions_path(@exercise.public_id), params: { restart: "true" }
    end

    assert_redirected_to exercise_path(@exercise.public_id)
    assert_equal "started", open.reload.status
  end

  test "CA-29 : reprendre la copie ouverte reste permis pendant la pause" do
    complete_copies(0, 10, 20)
    open = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    travel_to @at + 49.minutes do
      post exercise_sessions_path(@exercise.public_id)
    end

    assert_redirected_to exercise_session_path(open.public_id)
  end

  test "CA-30 : à 10 h 50 une copie s'ouvre" do
    complete_copies(0, 10, 20)
    sign_in_as @student

    travel_to @at + 50.minutes do
      assert_difference -> { Orm::ExerciseSession.where(status: "started").count }, 1 do
        post exercise_sessions_path(@exercise.public_id)
      end
    end
  end

  test "CA-31 : 3 copies non d'affilée, pas de pause" do
    complete_copies(0, 40, 50)
    sign_in_as @student

    travel_to @at + 55.minutes do
      assert_difference -> { Orm::ExerciseSession.where(status: "started").count }, 1 do
        post exercise_sessions_path(@exercise.public_id)
      end
    end
  end

  test "CA-33 : la pause est propre à l'exercice" do
    complete_copies(0, 10, 20)
    other = create_exercise(essential: @exercise.essential, title: "Mitose", questions: 2)
    sign_in_as @student

    travel_to @at + 30.minutes do
      assert_difference -> { Orm::ExerciseSession.where(exercise: other).count }, 1 do
        post exercise_sessions_path(other.public_id)
      end
    end
  end

  test "CA-34 : la page de l'exercice ne propose pas « Refaire l'exercice » et dit l'heure de reprise" do
    complete_copies(0, 10, 20)
    sign_in_as @student

    travel_to @at + 49.minutes do
      get exercise_path(@exercise.public_id)
    end

    assert_response :success
    assert_select "#start-exercise-form", 0
    assert_select "#restart-exercise-form", 0
    assert_select "#exercise_paused", text: pause_message
  end

  test "CA-34 : en pause avec une copie ouverte, « Reprendre » reste, « Recommencer » disparaît" do
    complete_copies(0, 10, 20)
    open = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    travel_to @at + 49.minutes do
      get exercise_path(@exercise.public_id)
    end

    assert_select "#exercise_actions a[href='#{exercise_session_path(open.public_id)}']"
    assert_select "#restart-exercise-form", 0
    assert_select "#exercise_paused", text: pause_message
  end

  test "CA-34 : la pause finie, « Refaire l'exercice » revient" do
    complete_copies(0, 10, 20)
    sign_in_as @student

    travel_to @at + 50.minutes do
      get exercise_path(@exercise.public_id)
    end

    assert_select "#start-exercise-form"
    assert_select "#exercise_paused", 0
  end
end
