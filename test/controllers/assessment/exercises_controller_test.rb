require "test_helper"

# AS-02, AS-39 — UDR-0138 §3.1. La page d'un exercice est la feuille : l'énoncé et les questions numérotées, rien à remplir.
# L'équipe et l'enseignant voient la solution sous chaque question ; l'élève jamais, et une seule action : « Faire l'exercice »
# ou « Reprendre ma copie ». Un brouillon, ou un exercice dont un parent n'est pas publié, répond 404 hors de l'équipe.
class Assessment::ExercisesControllerTest < ActionDispatch::IntegrationTest
  setup do
    course = create_course(name: "Génétique et évolution", level: create_level(name: "Tle"), series: create_series(name: "D"),
                           material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course:, name: "La méiose")
    @exercise = create_exercise(essential: @essential, title: "Méiose", statement: "Deux divisions successives.",
                                exercise_type: "evaluation")
    @exercise.questions.first.update!(explanation: "La méiose compte deux divisions.")
    @correct_ids = Orm::Answer.where(question: @exercise.questions, correct: true).pluck(:id)
    @student = create_student_for(course)
  end

  def scope = "assessment.exercises"
  def correct_mark = I18n.t("#{scope}.questions_preview.correct")

  test "l'élève voit la feuille : titre, énoncé, questions numérotées sans marque, et « Faire l'exercice »" do
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "title", text: /Méiose/
    assert_select "#exercise_header h1", text: "Méiose"
    assert_select "#exercise-sheet", text: /Deux divisions successives\./
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.questions", count: 2)}/
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.exercise_types.evaluation")}/
    assert_select "a[href='#{course_path(@essential.course.slug, anchor: "notion-#{@essential.slug}")}']"
    assert_select "#exercise_questions li.question", 2
    assert_select "#exercise_questions #sheet-question-1", text: /Question 1,/
    assert_select "#exercise_questions #sheet-question-2", text: /Question 2,/
    # CA-13 : les propositions d'une question à choix sont sur la feuille, toutes, sans case à cocher.
    @exercise.questions.order(:position).each_with_index do |question, index|
      assert_select "#sheet-question-#{index + 1} li.answer", question.answers.count
    end
    assert_select "#exercise_questions input, #exercise_questions textarea, #exercise_questions select, #exercise_questions form", 0
    # CA-13 : ni marque, ni explication, ni identifiant d'une bonne réponse dans la feuille de l'élève.
    assert_no_match(/#{correct_mark}|La méiose compte deux divisions|data-correct/, response.body)
    @correct_ids.each { |id| assert_no_match(/answer_#{id}\b|value="#{id}"/, response.body) }
    assert_select "#exercise_actions form#start-exercise-form[action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "input[name=restart]", 0
      assert_select "button[type=submit]", text: I18n.t("#{scope}.show.start")
    end
    assert_select "a[href='/teams/exercises/#{@exercise.public_id}/edit']", 0
    assert_select "#content_status_exercise_#{@exercise.public_id}", 0
  end

  test "l'élève qui a une copie en cours voit « Reprendre ma copie » et « Recommencer »" do
    started = create_exercise_session(student: @student, exercise: @exercise)
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise_actions a[href='#{exercise_session_path(started.public_id)}']", text: I18n.t("#{scope}.show.resume")
    assert_select "#exercise_actions form#restart-exercise-form[action='#{exercise_sessions_path(@exercise.public_id)}']" do
      assert_select "input[type=hidden][name=restart][value=true]"
      assert_select "button[type=submit]", text: I18n.t("#{scope}.show.restart")
    end
    assert_select "#start-exercise-form", 0
    assert_no_match(/#{correct_mark}/, response.body)
  end

  test "l'élève qui a déjà rendu une copie voit « Refaire l'exercice » et sa meilleure note sur 20" do
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 85)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 40)
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_select "#start-exercise-form button[type=submit]", text: I18n.t("#{scope}.show.redo")
    assert_select "#exercise_best", text: I18n.t("#{scope}.show.best", grade: 17)
    assert_select "#exercise_best.text-success"
    assert_select "*", text: /85 %/, count: 0
  end

  test "l'enseignant voit la solution et l'explication sous chaque question, sans bouton de session" do
    sign_in_as create_teacher

    get exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#exercise_questions li.question", 2
    assert_select "#exercise_questions", text: /La méiose compte deux divisions\./
    assert_select "#exercise_questions [data-correct]", text: /#{correct_mark}/
    assert_select "#exercise_actions", 0
    assert_select "#exercise_context", text: "La méiose"
    assert_select "form[action='#{exercise_sessions_path(@exercise.public_id)}']", 0
    assert_select "a[href='/teams/exercises/#{@exercise.public_id}/edit']", 0
  end

  test "la meilleure note est verte dès « 14/20 » affiché : 68 % oui, 67 % non" do
    sign_in_as @student
    session = create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 67)
    get exercise_path(@exercise.public_id)
    assert_select "#exercise_best.text-success", 0
    assert_select "#exercise_best", text: I18n.t("#{scope}.show.best", grade: 13)

    session.update!(score_percent: 68)
    get exercise_path(@exercise.public_id)
    assert_select "#exercise_best.text-success", text: I18n.t("#{scope}.show.best", grade: 14)
  end

  # CA-12, ADR-0091 §4.4 : la feuille de l'élève montre les nouveaux types sans solution ; l'enseignant la voit.
  test "nouveaux types : la solution pour l'enseignant, l'énoncé et la feuille seuls pour l'élève" do
    create_kind_question(exercise: @exercise, question_type: "fill_blank", content: "La capitale est ___ .", answers: %w[Yamoussoukro])
    create_kind_question(exercise: @exercise, question_type: "numeric", content: "Combien ?", answers: [ "42,75" ],
                         numeric_tolerance: BigDecimal("0.25"))
    create_kind_question(exercise: @exercise, question_type: "ordering", content: "Range.", answers: %w[Prophase Métaphase Anaphase])
    create_kind_question(exercise: @exercise, question_type: "matching", content: "Relie.", answers: [ %w[Gauche1 Droite1], %w[Gauche2 Droite2], %w[Gauche3 Droite3] ])

    sign_in_as create_teacher
    get exercise_path(@exercise.public_id)
    assert_select "#exercise_questions [data-correct]", text: /Yamoussoukro/
    assert_select "#exercise_questions [data-correct]", text: /42,75.*0,25/m
    assert_select "#exercise_questions [data-correct] ol li", text: "Métaphase"
    assert_select "#exercise_questions [data-correct] li", text: "Gauche2 → Droite2"

    sign_in_as @student
    get exercise_path(@exercise.public_id)
    assert_select "#exercise_questions li.question", 6
    # La feuille montre les étapes et les deux colonnes, mélangées ; jamais la valeur, la marge ni la bonne association.
    %w[Prophase Métaphase Anaphase Gauche1 Droite1 Droite3].each { assert_match(/#{it}/, response.body) }
    %w[Yamoussoukro 42,75 0,25].each { assert_no_match(/#{it}/, response.body) }
    assert_select "#exercise_questions [data-correct]", 0
    assert_no_match(/Gauche2 → Droite2/, response.body)
  end

  # CA-8, UDR-0145 §3.3 : chaque question est une carte numérotée qui dit son format.
  test "chaque question est une carte numérotée qui dit son format, jamais le nombre de bonnes propositions" do
    exercise = create_exercise(essential: @essential, questions: 0, statement: "Deux divisions successives.")
    formats = { "true_false" => "Vrai ou faux", "single_choice" => "Une seule réponse", "multiple_correct_2" => "Plusieurs réponses",
                "multiple_correct_3" => "Plusieurs réponses" }
    formats.each_key.with_index do |type, index|
      correct = { "true_false" => 1, "single_choice" => 1, "multiple_correct_2" => 2, "multiple_correct_3" => 3 }.fetch(type)
      question = exercise.questions.create!(position: index + 1, content: "Énoncé #{index + 1}", question_type: type)
      4.times { |rank| question.answers.create!(position: rank + 1, content: "Choix #{rank + 1}", correct: rank < correct) }
    end
    create_kind_question(exercise:, question_type: "fill_blank", content: "Le ___ .", answers: %w[nucléole])
    create_kind_question(exercise:, question_type: "numeric", content: "Combien ?", answers: [ "4" ])
    create_kind_question(exercise:, question_type: "ordering", content: "Range.", answers: %w[A B C])
    create_kind_question(exercise:, question_type: "matching", content: "Relie.", answers: [ %w[G1 D1], %w[G2 D2], %w[G3 D3] ])
    expected = formats.values + [ "Texte à trous", "Réponse en nombre", "Remettre dans l'ordre", "Relier" ]

    sign_in_as @student
    get exercise_path(exercise.public_id)

    assert_select "#exercise_statement_card", text: /Deux divisions successives\./
    assert_select "#exercise-sheet[role=region]"
    assert_select "#exercise_questions li.question", expected.size
    expected.each_with_index do |label, index|
      assert_select "#sheet-question-#{index + 1}.rounded-card"
      assert_select "#sheet-question-#{index + 1} > div:first-child > span:first-child", text: "#{index + 1}"
      assert_select "#sheet-question-#{index + 1}-format", text: label
      assert_select "#sheet-question-#{index + 1} .sr-only", text: "Question #{index + 1},"
    end
    assert_equal 2, response.body.scan(">Plusieurs réponses<").size
    assert_no_match(/\d propositions? correctes?/, response.body)
  end

  test "les formats restants se disent : sélection, rédigée, cahier" do
    exercise = create_exercise(essential: @essential, questions: 0)
    %w[select written notebook].each_with_index do |type, index|
      create_kind_question(exercise:, question_type: type, content: "Q#{index} ___", answers: %w[Bon])
    end

    sign_in_as @student
    get exercise_path(exercise.public_id)

    assert_select "#sheet-question-1-format", text: "Choix dans une liste"
    assert_select "#sheet-question-2-format", text: "Réponse rédigée"
    assert_select "#sheet-question-3-format", text: "Sur le cahier"
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
    assert_select "#exercise_header ~ #exercise_assign"
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
    # CA-29, ADR-0113 §4.6: the ⋮ menu carries the transitions only; « Modifier » is gone, the lesson is imported again.
    assert_select "button[aria-haspopup=menu][aria-label=?]", I18n.t("#{scope}.show.actions", name: exercise.title)
    assert_select "[role=menu] a[role=menuitem][href='/teams/exercises/#{exercise.public_id}/edit']", 0
    assert_select "#exercise_questions [data-correct]", text: /#{correct_mark}/
    assert_select "#exercise_actions", 0
    assert_select "#exercise_context", text: "La méiose"
  end

  test "un exercice sans question ni description, vu par l'équipe, le dit" do
    exercise = create_exercise(essential: create_essential(course: create_course(series: nil)), status: "draft", questions: 0)
    sign_in_as create_team_member

    get exercise_path(exercise.public_id)

    assert_response :success
    assert_select "#exercise_header", text: /#{I18n.t("#{scope}.show.questions", count: 0)}/
    assert_select "#exercise_questions_empty", text: /#{I18n.t("#{scope}.show.no_questions")}/
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

  # CA-14 : un exercice de toute la leçon n'a pas de notion ; l'élève du niveau, l'enseignant et l'équipe le lisent (200),
  # l'élève d'un autre niveau reçoit 404.
  test "exercice de toute la leçon : 200 pour le niveau, l'enseignant et l'équipe ; 404 pour un autre niveau" do
    lesson = create_lesson_wide_exercise(course: @essential.course, title: "Bilan du chapitre", statement: "Soit un triangle ABC.")

    [ @student, create_teacher, create_team_member ].each do |user|
      sign_in_as user
      get exercise_path(lesson.public_id)

      assert_response :success
      assert_select "#exercise_context", text: I18n.t("#{scope}.show.lesson_wide")
      assert_select "#exercise-sheet", text: /Soit un triangle ABC\./
      assert_select "a[href='#{course_path(@essential.course.slug, anchor: "toute-la-lecon")}']"
      sign_out
    end

    sign_in_as create_student_for(create_course(level: create_level(name: "6e")))
    get exercise_path(lesson.public_id)
    assert_response :not_found
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
