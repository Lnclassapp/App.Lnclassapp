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
    @student = create_student_for(course)
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
    assert_no_match(/#{correct_mark}|La méiose compte deux divisions/, response.body)
    @correct_ids.each { |id| assert_no_match(/answer_#{id}\b|value="#{id}"/, response.body) }

    # UDR-0021, amendement du 2026-10-02 : la fiche n'est nommée que par le lien retour (R6) ; l'aide passe en infobulle (R4).
    assert_select "#exercise_context", text: "Génétique et évolution"
    assert_select "#exercise_header", text: /Fiche essentielle :/, count: 0
    assert_select "#exercise_questions_title details", text: /#{I18n.t("#{scope}.questions_preview.student_hint")}/
    assert_select "#exercise_questions p", text: /#{I18n.t("#{scope}.questions_preview.student_hint")}/, count: 0
    assert_select "#exercise_questions[data-controller=reveal][data-reveal-step-value='3']"
    assert_select "#exercise_questions li.question[data-reveal-target=item]", 2
    assert_select "#exercise_questions li.question[hidden]", 0
    assert_select "#exercise_questions [data-reveal-target=button]", 0

    assert_select "#student_progress dt", text: I18n.t("#{scope}.student_progress.best_score")
    assert_select "#student_progress dd", text: I18n.t("#{scope}.student_progress.no_score"), count: 2
    assert_select "#student_progress", text: /Aucune session terminée/, count: 0
    assert_select "#student_progress", text: /#{I18n.t("#{scope}.student_progress.no_badge")}/
    assert_select "#student_progress form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "input[name=restart]", 0
      assert_select "button[type=submit]", text: I18n.t("#{scope}.student_progress.start")
    end
    assert_select "a[href='#{edit_teams_exercise_path(@exercise.public_id)}']", 0
    assert_select "#content_status_exercise_#{@exercise.public_id}", 0
  end

  test "l'élève qui a une session en cours voit « Reprendre » et « Recommencer », sa meilleure note, sa maîtrise et son badge" do
    best = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 40)
    create_badge(student: @student, exercise: @exercise, level: "gold", session: best)
    started = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#student_progress" do
      # UDR-0021, amendement du 2026-10-02 : la meilleure note sur 20, la seule forme de la note pour l'élève (R6).
      assert_select "*", text: /#{I18n.t("#{scope}.student_progress.best_score")}/
      assert_select "dd", text: "17/20"
      assert_select "*", text: /85 %/, count: 0
      assert_select "*", text: /Acquis/
      assert_select "*", text: /#{I18n.t("#{scope}.student_progress.badge_level", level: "Or")}/
      assert_select "*", text: /#{I18n.t("#{scope}.student_progress.completed", count: 2)}/
      assert_select "a[href='#{exercise_session_path(started.public_id)}']", text: I18n.t("#{scope}.student_progress.resume")
      assert_select "form[method=post][action='#{exercise_sessions_path(@exercise.public_id)}']", 1 do
        assert_select "input[type=hidden][name=restart][value=true]"
        assert_select "button[type=submit]", text: I18n.t("#{scope}.student_progress.restart")
      end
      assert_select "button", text: I18n.t("#{scope}.student_progress.start"), count: 0
      # « Recommencer » s'explique dans son infobulle, plus dans un paragraphe permanent (R4).
      assert_select "details", text: /#{Regexp.escape(I18n.t("#{scope}.student_progress.restart_hint"))}/
      assert_select "p", text: /#{Regexp.escape(I18n.t("#{scope}.student_progress.restart_hint"))}/, count: 0
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
    assert_select "#exercise_questions p", text: /#{I18n.t("#{scope}.questions_preview.reveal_hint")}/
    assert_select "#student_progress", 0
    # Décision du porteur (2026-10-02) : l'enseignant garde l'écran inchangé — contexte complet, toutes les questions.
    assert_select "#exercise_context", text: I18n.t("#{scope}.show.context", course: "Génétique et évolution", essential: "La méiose")
    assert_select "#exercise_questions[data-controller=reveal]", 0
    assert_select "#exercise_questions [data-reveal-target]", 0
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
    assert_select "a[href='#{edit_teams_exercise_path(@exercise.public_id)}']", 0
  end

  # RE-22 — UDR-0069 §3.8 : après l'en-tête, la carte « Assigner à mes classes », une bascule par classe de l'enseignant
  # du niveau et de la série du cours ; les libellés nomment l'exercice et la classe.
  test "l'enseignant assigne depuis la page : « Assigner à mes classes », une bascule par classe de Tle D" do
    course = @essential.course
    school = create_school
    tle_d1, tle_d2 = [ "Tle D 1", "Tle D 2" ].map { |name| create_classroom(school:, level: course.level, series: course.series, name:) }
    tle_c1 = create_classroom(school:, level: course.level, series: create_series(name: "C"), name: "Tle C 1")
    teacher = create_teacher(school:, classrooms: [ tle_c1, tle_d2, tle_d1 ])
    assignment = create_assignment(classroom: tle_d2, assignable: @exercise, by: teacher)
    sign_in_as teacher

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise_header ~ div > #exercise_assign"
    assert_select "#exercise_assign" do
      assert_select "h2", text: I18n.t("#{scope}.show.assign_title")
      assert_select "ul[aria-label=?]", I18n.t("#{scope}.show.assign_targets", title: "Méiose") do |list|
        # UDR-0077 §3.3 : la ligne compacte de la fiche — la classe d'abord, la bascule (✕ seul) à droite.
        assert_equal [ "Tle D 1", "Tle D 2" ], list.css("li [id^='assignment_'] > div > p:first-child").map { it.text.strip }
      end
      assert_select "[id^='assignment_']", 2
      assert_select "#assignment_#{tle_d1.public_id}_Exercise_#{@exercise.public_id} a[data-turbo-frame=modal][aria-label=?]",
                    "Assigner « Méiose » à Tle D 1"
      assert_select "#assignment_#{tle_d2.public_id}_Exercise_#{@exercise.public_id}" do
        assert_select "*", text: /Assigné/
        assert_select "form[action='#{archive_assignment_path(assignment.public_id)}']:has(input[name=compact]) button.ui-icon-button[aria-label=?]",
                      "Retirer « Méiose » de Tle D 2"
      end
      assert_select "#exercise_assign_none", 0
    end
    assert_select "[id^='assignment_#{tle_c1.public_id}_']", 0
  end

  test "l'enseignant sans classe de Tle D lit « Aucune de vos classes n'est en Tle D. », sans bascule" do
    sign_in_as create_teacher(classrooms: [ create_classroom(level: @essential.course.level, series: create_series(name: "C")) ])

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise_assign #exercise_assign_none", text: "Aucune de vos classes n'est en Tle D."
    assert_select "[id^='assignment_']", 0
  end

  # RE-26 — UDR-0069 §3.8 : ni l'équipe ni l'élève n'ont la carte ; le menu ⋮ de l'équipe est inchangé.
  test "l'équipe et l'élève ne voient pas « Assigner à mes classes »" do
    create_teacher(classrooms: [ create_classroom(level: @essential.course.level, series: @essential.course.series) ])

    [ [ create_team_member, 1 ], [ @student, 0 ] ].each do |user, menus|
      sign_in_as user
      get exercise_path(@exercise.public_id)

      assert_response :success
      assert_select "#exercise_assign", 0
      assert_select "[id^='assignment_']", 0
      assert_select "button[aria-haspopup=menu][aria-label=?]", I18n.t("#{scope}.show.actions", name: "Méiose"), menus
      sign_out
    end
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
    assert_select "#exercise_context", text: I18n.t("#{scope}.show.context", course: "Génétique et évolution", essential: "La méiose")
    assert_select "#exercise_questions [data-reveal-target]", 0
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
