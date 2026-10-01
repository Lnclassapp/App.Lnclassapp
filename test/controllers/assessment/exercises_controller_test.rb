require "test_helper"

# AS-02, AS-39 — UDR-0021. La page d'un exercice : titre, description, nombre de questions, matière, aperçu des questions.
# L'équipe et l'enseignant voient les propositions correctes marquées ; l'élève jamais, mais il voit sa progression et
# « Commencer » ou « Reprendre ». Un brouillon, ou un exercice dont un parent n'est pas publié, répond 404 hors de l'équipe.
class Assessment::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                           material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course:, name: "La méiose")
    @exercise = create_exercise(essential: @essential, title: "Méiose", description: "Deux divisions successives.",
                                exercise_type: "evaluation")
    @exercise.questions.first.update!(explanation: "La méiose compte deux divisions.")
    @correct_ids = Orm::Answer.where(question: @exercise.questions, correct: true).pluck(:id)
    @student = create_student
  end

  def scope = "assessment.exercises"
  def correct_mark = I18n.t("#{scope}.questions_preview.correct")

  test "l'élève voit le titre, la description, les questions sans marque, sa progression et « Commencer »" do
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "#exercise_header h1", text: "Méiose"
    assert_select "#exercise_header", text: /Deux divisions successives\./
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.questions", count: 2)}/
    assert_select "#exercise_header", text: /SVT/
    assert_select "#exercise_header", text: /Tle D/
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.exercise_types.evaluation")}/
    assert_select "#exercise_header a[href='#{course_essential_path(@essential.course.slug, @essential.slug)}']"
    assert_select "#exercise_questions [data-controller=math] li.question", 2
    assert_select "#exercise_questions", text: /Question 1/
    assert_select "#exercise_questions", text: /Proposition 4/
    assert_select "#exercise_questions", text: /#{I18n.t("#{scope}.questions_preview.student_hint")}/
    assert_no_match(/#{correct_mark}|La méiose compte deux divisions/, response.body)
    @correct_ids.each { |id| assert_no_match(/answer_#{id}\b|value="#{id}"/, response.body) }

    assert_select "#student_progress", text: /#{I18n.t("#{scope}.student_progress.no_score")}/
    assert_select "#student_progress", text: /#{I18n.t("#{scope}.student_progress.no_badge")}/
    assert_select "#student_progress form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "input[name=restart]", 0
      assert_select "button[type=submit]", text: I18n.t("#{scope}.student_progress.start")
    end
    assert_select "a[href='#{edit_teams_exercise_path(@exercise.public_id)}']", 0
    assert_select "#content_status_exercise_#{@exercise.public_id}", 0
  end

  test "l'élève qui a une session en cours voit « Reprendre » et « Recommencer », son meilleur score, sa maîtrise et son badge" do
    best = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 40)
    create_badge(student: @student, exercise: @exercise, level: "gold", session: best)
    started = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#student_progress" do
      assert_select "*", text: /85 %/
      assert_select "*", text: /Acquis/
      assert_select "*", text: /#{I18n.t("#{scope}.student_progress.badge_level", level: "Or")}/
      assert_select "*", text: /#{I18n.t("#{scope}.student_progress.completed", count: 2)}/
      assert_select "a[href='#{exercise_session_path(started.public_id)}']", text: I18n.t("#{scope}.student_progress.resume")
      assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']", 1 do
        assert_select "input[type=hidden][name=restart][value=true]"
        assert_select "button[type=submit]", text: I18n.t("#{scope}.student_progress.restart")
      end
      assert_select "button", text: I18n.t("#{scope}.student_progress.start"), count: 0
    end
    assert_no_match(/#{correct_mark}/, response.body)
  end

  test "l'enseignant voit les propositions correctes marquées et l'explication, sans progression ni bouton de session" do
    sign_in_as create_teacher

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise_questions li.answer", 8
    assert_select "#exercise_questions li.answer[data-correct]", 2
    @correct_ids.each { |id| assert_select "#answer_#{id}[data-correct]", text: /#{correct_mark}/ }
    assert_select "#exercise_questions", text: /La méiose compte deux divisions\./
    assert_select "#exercise_questions", text: /#{I18n.t("#{scope}.questions_preview.reveal_hint")}/
    assert_select "#student_progress", 0
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
    assert_select "a[href='#{edit_teams_exercise_path(@exercise.public_id)}']", 0
  end

  test "l'équipe ouvre un brouillon : statut, transitions, « Modifier » en modale et propositions correctes" do
    exercise = create_exercise(essential: @essential, status: "draft")
    sign_in_as create_team_member

    get exercise_path(exercise.public_id)

    assert_response :success
    assert_select "#content_status_exercise_#{exercise.public_id}", text: /Brouillon/
    # Épuration des en-têtes (2026-09-30) : le statut seul dans l'en-tête, la transition dans le menu ⋮.
    assert_select "#content_status_exercise_#{exercise.public_id} form", 0
    assert_select "[role=menu] #content_transitions_exercise_#{exercise.public_id} a[role=menuitem][data-turbo-method=patch]" \
                  "[href='#{publish_teams_exercise_path(exercise.public_id)}']"
    # UDR-0042: « Modifier » lives in the ⋮ menu of the exercise, even alone.
    assert_select "button[aria-haspopup=menu][aria-label=?]", I18n.t("#{scope}.show.actions", name: exercise.title)
    assert_select "[role=menu] a[role=menuitem][href='#{edit_teams_exercise_path(exercise.public_id)}'][data-turbo-frame=modal]",
                  text: I18n.t("#{scope}.show.edit")
    assert_select "#exercise_questions li.answer[data-correct]", 2
    assert_select "#student_progress", 0
  end

  test "un exercice sans question ni description, vu par l'équipe, le dit" do
    exercise = create_exercise(essential: create_essential(course: create_course(series: nil)), status: "draft", questions: 0)
    sign_in_as create_team_member

    get exercise_path(exercise.public_id)

    assert_response :success
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.questions", count: 0)}/
    assert_select "#exercise_questions_empty", text: /#{I18n.t("#{scope}.questions_preview.empty_title")}/
    assert_select "#exercise_description", 0
  end

  test "un brouillon, une fiche en brouillon ou un exercice archivé répond 404 à l'élève et à l'enseignant" do
    draft = create_exercise(essential: @essential, status: "draft")
    archived = create_exercise(essential: @essential, status: "archived")
    in_draft_essential = create_exercise(essential: create_essential(course: @essential.course, status: "draft"))

    [ @student, create_teacher ].each do |user|
      sign_in_as user
      [ draft, archived, in_draft_essential ].each do |exercise|
        get exercise_path(exercise.public_id)

        assert_response :not_found
        assert_no_match(/#{exercise.title}|Proposition 1/, response.body)
      end
      sign_out
    end
  end

  test "un exercice inconnu répond 404" do
    sign_in_as @student

    get exercise_path("inconnu")

    assert_response :not_found
  end

  test "sans connexion, la page renvoie à la connexion" do
    get exercise_path(@exercise.public_id)

    assert_redirected_to new_session_path
  end
end
