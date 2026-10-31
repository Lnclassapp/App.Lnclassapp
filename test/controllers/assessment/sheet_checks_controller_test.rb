require "test_helper"

# prepare-interros-cahier, Lot C (CA-3, 4, 5, 10, 17 ; UDR feuilles-prepare-interros-et-devoirs §3) : « Vérifier ma réponse » rend une vraie
# copie depuis la feuille de la leçon puis ouvre la page de résultat existante (303, avec ou sans JS ; Lot C bis) ; la pause, l'archivage,
# la panne et un devoir à rendre s'affichent dans l'exercice (Turbo Stream), sans rien écrire.
class Assessment::SheetChecksControllerTest < ActionDispatch::IntegrationTest
  STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup do
    @course = create_course
    @notion = create_essential(course: @course, position: 1)
    @exercise = create_exercise(essential: @notion, questions: 5)
    @classroom = create_classroom(level: @course.level, series: @course.series)
    @student = create_student(classroom: @classroom)
    @questions = @exercise.questions.order(:position).to_a
  end

  # La feuille poste le rang de la proposition dans l'ordre des positions (la bonne est la première du factory), jamais un id.
  def answers(right:) = @questions.each_with_index.to_h { |question, index| [ question.id.to_s, { display_order: [ index < right ? "0" : "1" ] } ] }

  def check(right: 5, exercise: @exercise, headers: STREAM, **extra)
    post(exercise_sheet_check_path(exercise.public_id), params: { copy: { answers: answers(right:) }, **extra }, headers:)
  end

  # Le partiel d'un exercice de la feuille, tel que « Ma classe » le rendra : la copie rendue (nil avant le rendu) et le devoir.
  def sheet_html(copy: nil, assignment_public_id: nil)
    exercise = Queries::Catalog::PrepareSheetsQuery::SheetExercise.new(
      public_id: @exercise.public_id, number: 1, title: "Exercice", statement: nil, statement_blocks: nil, figure: nil, hint: nil,
      questions: [], copy:
    )
    Nokogiri::HTML5.fragment(ApplicationController.render(partial: "catalog/courses/sheets/exercise",
                                                          locals: { exercise:, mode: :student, assignment_public_id: }))
  end

  test "4 justes sur 5 : une copie terminée, puis la page de résultat de la copie (CA-3)" do
    sign_in_as @student

    assert_difference -> { Orm::ExerciseSession.where(student: @student, status: "completed").count }, 1 do
      check(right: 4)
    end

    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)
    assert_equal [ "completed", 4, 5 ], [ session.status, session.correct_count, session.question_count ]
    assert_response :see_other
    assert_redirected_to exercise_session_result_path(session.public_id, return_to: "sheet")
  end

  test "la page de résultat garde son contenu (note sur 20) et offre le retour à l'exercice de la feuille, ancre comprise" do
    sign_in_as @student
    check(right: 4)
    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)

    get exercise_session_result_path(session.public_id, return_to: "sheet")

    assert_response :success
    assert_select "#session_grade", text: "16/20"
    back = "#{course_path(@course.slug)}#sheet-exercise-#{@exercise.public_id}"
    assert_select "a[href=?]", back, text: "Retour à la leçon"
  end

  test "return_to ne prend que deux cibles : la feuille, ou Ma classe ; tout autre valeur laisse le retour d'aujourd'hui" do
    sign_in_as @student
    check
    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)

    get exercise_session_result_path(session.public_id, return_to: "class")
    assert_select "a[href=?]", student_classroom_path, text: "Retour à Ma classe"

    get exercise_session_result_path(session.public_id, return_to: "https://exemple.org/")
    assert_select "a[href*='exemple']", 0
    assert_select "a[href=?]", "#{course_path(@course.slug)}#notion-#{@notion.slug}", text: "Retour à la leçon"

    get exercise_session_result_path(session.public_id)
    assert_select "a[href=?]", "#{course_path(@course.slug)}#notion-#{@notion.slug}", text: "Retour à la leçon"
  end

  test "au retour sur la feuille, l'exercice vérifié montre « Réussi », « Voir ma correction » et « Refaire l'exercice », sans note ni correction (CA-4)" do
    sign_in_as @student
    create_exercise(essential: @notion, questions: 1)
    create_exercise(essential: @notion, questions: 1)
    check
    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)

    get course_path(@course.slug)

    assert_select "#sheet-exercise-#{@exercise.public_id}" do
      assert_select ".ps-status", text: "Réussi"
      assert_select "a[href=?]", exercise_session_result_path(session.public_id, return_to: "sheet"), text: "Voir ma correction"
      assert_select "button.ps-btn--redo", text: "Refaire l'exercice"
      assert_select ".ps-result", 0
      assert_select "button.ps-btn--primary[hidden]", text: "Vérifier ma réponse"
    end
    assert_select ".ps-progress", text: "1 / 3 exercice réussi"
    assert_no_match(/Ta note|Mention :/, response.body)
  end

  test "la copie compte comme n'importe quelle copie : note, maîtrise et pause suivent SubmitExerciseCopy" do
    sign_in_as @student

    check(right: 5)

    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)
    assert_equal 100, session.score_percent
    assert_equal 5, Orm::QuestionAttempt.where(exercise_session: session, correct: true).count
  end

  test "la pause de 3 copies d'affilée : aucune copie, l'heure de reprise dans l'exercice (CA-5)" do
    3.times { create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: 5.minutes.ago) }
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      check
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert][id=?]", "sheet-error-#{@exercise.public_id}", text: /Tu as rendu 3 copies d'affilée\. Tu pourras recommencer à \d{2} h \d{2}\./
    assert_select "turbo-stream[action=replace][target=?]", "sheet-exercise-#{@exercise.public_id}", count: 0
  end

  test "un exercice archivé après l'ouverture de la page : « Cet exercice n'existe plus. », rien n'est écrit (CA-10)" do
    @exercise.update!(status: "archived", archived_at: Time.current)
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      check
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "Cet exercice n'existe plus."
  end

  test "une panne : « La copie n'est pas partie. Réessaie. » et l'erreur est signalée (CA-10)" do
    sign_in_as @student
    repository = Repositories::Assessment::ExerciseSessionRepository
    original = repository.instance_method(:start)
    repository.define_method(:start) { |**| raise ActiveRecord::StatementInvalid, "panne" }
    reported = []
    contexts = []
    subscriber = Struct.new(:reported, :contexts) do
      def report(error, context: {}, **)
        reported << error.class
        contexts << context.slice(:user_id, :exercise_public_id, :assignment_public_id)
      end
    end.new(reported, contexts)
    Rails.error.subscribe(subscriber)

    begin
      check
    ensure
      Rails.error.unsubscribe(subscriber)
      repository.define_method(:start, original)
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "La copie n'est pas partie. Réessaie."
    assert_equal [ ActiveRecord::StatementInvalid ], reported
    assert_equal [ { user_id: @student.id, exercise_public_id: @exercise.public_id, assignment_public_id: nil } ], contexts
  end

  test "une réponse illisible (un nombre attendu) : un message qui la désigne, pas « La copie n'est pas partie » (R1)" do
    numeric = create_exercise(essential: @notion, questions: 0)
    create_kind_question(exercise: numeric, question_type: "numeric", answers: [ "4" ])
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      post exercise_sheet_check_path(numeric.public_id), params: { copy: { answers: { numeric.questions.first.id.to_s => { response_text: "abc" } } } }, headers: STREAM
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "Une réponse n'est pas lisible : vérifie-la (un nombre est attendu pour un calcul), puis réessaie."
    assert_no_match(/La copie n'est pas partie/, response.body)
  end

  test "sans JavaScript, une réponse illisible revient à la leçon avec son message (R1)" do
    numeric = create_exercise(essential: @notion, questions: 0)
    create_kind_question(exercise: numeric, question_type: "numeric", answers: [ "4" ])
    sign_in_as @student

    post exercise_sheet_check_path(numeric.public_id), params: { copy: { answers: { numeric.questions.first.id.to_s => { response_text: "abc" } } } }

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{numeric.public_id}")
    assert_match(/Une réponse n'est pas lisible/, flash[:alert])
  end

  test "un exercice assigné et pas encore rendu est refusé sans ouvrir de session, avec le lien « Ma classe » (CA-17)" do
    classroom = @classroom
    create_assignment(classroom:, assignable: @exercise)
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      check
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "Ce devoir est à rendre : ouvre-le dans Ma classe."
    assert_select "template p.ps-error a[href=?]", student_classroom_path, text: "Ma classe"
  end

  test "un devoir déjà rendu se vérifie de nouveau depuis la leçon" do
    classroom = @classroom
    assignment = create_assignment(classroom:, assignable: @exercise)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", classroom_assignment_id: assignment.id)
    sign_in_as @student

    check

    assert_response :see_other
  end

  test "la leçon n'offre pas « Vérifier ma réponse » pour un devoir à rendre (CA-17)" do
    create_assignment(classroom: @classroom, assignable: @exercise)
    other = create_exercise(essential: @notion, questions: 1)
    sign_in_as @student

    get course_path(@course.slug)

    assert_select "#sheet-exercise-#{@exercise.public_id}" do
      assert_select "button.ps-btn--primary", count: 0
      assert_select "button.ps-btn--hint", count: 0
      assert_select "p.ps-error", text: "Ce devoir est à rendre : ouvre-le dans Ma classe."
    end
    assert_select "#sheet-exercise-#{other.public_id} button.ps-btn--primary", text: "Vérifier ma réponse"
  end

  test "sans JavaScript : la même redirection vers la page de résultat de la copie" do
    sign_in_as @student

    check(headers: {})

    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise)
    assert_response :see_other
    assert_redirected_to exercise_session_result_path(session.public_id, return_to: "sheet")
    assert_equal 1, Orm::ExerciseSession.where(student: @student, status: "completed").count
  end

  test "sans JavaScript, un refus revient à la leçon avec son message" do
    @exercise.update!(status: "archived", archived_at: Time.current)
    sign_in_as @student

    check(headers: {})

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{@exercise.public_id}")
    assert_equal "Cet exercice n'existe plus.", flash[:alert]
  end

  # Un refus dans l'exercice (Turbo Stream) se relit, sans JavaScript, dans le message de retour à la leçon : un par code d'erreur.
  test "sans JavaScript, la pause revient à la leçon avec l'heure de reprise" do
    3.times { create_exercise_session(student: @student, exercise: @exercise, status: "completed", completed_at: 5.minutes.ago) }
    sign_in_as @student

    check(headers: {})

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{@exercise.public_id}")
    assert_match(/Tu as rendu 3 copies d'affilée\. Tu pourras recommencer à \d{2} h \d{2}\./, flash[:alert])
  end

  test "sans JavaScript, un devoir à rendre revient à la leçon avec le lien « Ma classe »" do
    create_assignment(classroom: @classroom, assignable: @exercise)
    sign_in_as @student

    check(headers: {})

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{@exercise.public_id}")
    assert_equal "Ce devoir est à rendre : ouvre-le dans Ma classe.", flash[:alert]
  end

  test "sans JavaScript, rendre un devoir déjà rendu revient à la leçon avec son message" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise)
    sign_in_as @student
    check(assignment_public_id: assignment.public_id)

    check(headers: {}, assignment_public_id: assignment.public_id)

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{@exercise.public_id}")
    assert_equal "Ce devoir n'est plus à rendre.", flash[:alert]
  end

  test "sans JavaScript, une panne revient à la leçon avec « Réessaie. »" do
    sign_in_as @student
    repository = Repositories::Assessment::ExerciseSessionRepository
    original = repository.instance_method(:start)
    repository.define_method(:start) { |**| raise ActiveRecord::StatementInvalid, "panne" }

    begin
      check(headers: {})
    ensure
      repository.define_method(:start, original)
    end

    assert_redirected_to course_path(@course.slug, anchor: "sheet-exercise-#{@exercise.public_id}")
    assert_equal "La copie n'est pas partie. Réessaie.", flash[:alert]
  end

  test "une copie déjà enregistrée par une autre requête : « La copie n'est pas partie. Réessaie. », rien n'est écrit" do
    sign_in_as @student
    repository = Repositories::Assessment::ExerciseSessionRepository
    original = repository.instance_method(:record_copy)
    repository.define_method(:record_copy) { |**| :duplicate }

    begin
      assert_no_difference -> { Orm::ExerciseSession.where(status: "completed").count } do
        check
      end
    ensure
      repository.define_method(:record_copy, original)
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "La copie n'est pas partie. Réessaie."
  end

  # Ce que l'élève poste est lu champ par champ : tout ce qui n'est pas un champ de copie est ignoré, jamais une erreur serveur.
  test "sans copie postée ou avec des réponses qui ne sont pas des champs, la copie est lue vide : aucune bonne réponse" do
    sign_in_as @student

    post exercise_sheet_check_path(@exercise.public_id), headers: STREAM
    post exercise_sheet_check_path(@exercise.public_id), params: { copy: "x" }, headers: STREAM
    post exercise_sheet_check_path(@exercise.public_id), params: { copy: { answers: "x" } }, headers: STREAM

    assert_response :see_other
    assert_equal [ 0, 0, 0 ], Orm::ExerciseSession.where(student: @student, status: "completed").pluck(:correct_count)
  end

  test "un champ de réponse qui n'est pas un ensemble de champs est lu vide : aucune bonne réponse" do
    sign_in_as @student

    post exercise_sheet_check_path(@exercise.public_id), params: { copy: { answers: { @questions.first.id.to_s => "x" } } }, headers: STREAM

    assert_response :see_other
    assert_equal [ 0 ], Orm::ExerciseSession.where(student: @student, status: "completed").pluck(:correct_count)
  end

  test "un visiteur est envoyé à la connexion, sans copie" do
    check

    assert_redirected_to new_session_path
    assert_equal 0, Orm::ExerciseSession.count
  end

  test "un enseignant reçoit 403" do
    sign_in_as create_teacher

    check

    assert_response :forbidden
  end

  test "un élève hors du niveau de la leçon reçoit 404, sans copie" do
    outsider = create_student(classroom: create_classroom(level: create_level, series: nil))
    sign_in_as outsider

    check

    assert_response :not_found
    assert_equal 0, Orm::ExerciseSession.count
  end

  test "un exercice inconnu reçoit 404" do
    sign_in_as @student

    post exercise_sheet_check_path("InConnu0000000"), params: { copy: { answers: {} } }, headers: STREAM

    assert_response :not_found
  end

  # ---- Rendre à l'enseignant (CA-16, memo Q17) ----

  test "« Rendre à l'enseignant » : la copie est rattachée à l'assignation et l'enseignant la voit dans son suivi" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise)
    sign_in_as @student

    check(right: 4, assignment_public_id: assignment.public_id)

    session = Orm::ExerciseSession.find_by!(student: @student, exercise: @exercise, status: "completed")
    assert_redirected_to exercise_session_result_path(session.public_id, return_to: "class")
    assert_equal assignment.id, session.classroom_assignment_id
    scores = Queries::Assessment::AssignmentScores.for(classroom_id: @classroom.id, assignment_ids: [ assignment.id ])
    assert_equal [ [ @student.id, [ 80 ] ] ], scores.fetch(assignment.id).map { [ it.student_id, it.scores ] }
  end

  test "après le rendu, une copie refaite (« Vérifier ma réponse ») n'est pas rattachée : l'enseignant garde la copie rendue" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise)
    sign_in_as @student
    check(right: 4, assignment_public_id: assignment.public_id)
    handed_in = Orm::ExerciseSession.find_by!(student: @student, status: "completed")

    check(right: 5)

    assert_response :see_other
    assert_equal 2, Orm::ExerciseSession.where(student: @student, status: "completed").count
    assert_equal [ assignment.id, nil ], Orm::ExerciseSession.where(student: @student, status: "completed").order(:id).pluck(:classroom_assignment_id)
    scores = Queries::Assessment::AssignmentScores.for(classroom_id: @classroom.id, assignment_ids: [ assignment.id ])
    assert_equal [ handed_in.id ], scores.fetch(assignment.id).map(&:best_session_id)
  end

  test "rendre un devoir déjà rendu est refusé sans copie" do
    assignment = create_assignment(classroom: @classroom, assignable: @exercise)
    sign_in_as @student
    check(assignment_public_id: assignment.public_id)

    assert_no_difference -> { Orm::ExerciseSession.count } do
      check(assignment_public_id: assignment.public_id)
    end

    assert_response :unprocessable_entity
    assert_select "template p.ps-error[role=alert]", text: "Ce devoir n'est plus à rendre."
  end

  test "l'assignation d'une autre classe ou d'un autre exercice est refusée (403), sans session" do
    other_class = create_classroom(level: @course.level, series: @course.series)
    elsewhere = create_assignment(classroom: other_class, assignable: @exercise)
    another = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @notion, questions: 1))
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      check(assignment_public_id: elsewhere.public_id)
      assert_response :forbidden
      check(assignment_public_id: another.public_id)
      assert_response :forbidden
      check(assignment_public_id: "InConnu0000000")
      assert_response :forbidden
    end
  end

  test "l'exercice à rendre affiche « Rendre à l'enseignant » et un champ caché, sans note ni correction avant le rendu" do
    html = sheet_html(assignment_public_id: "AsSiGn00000001")

    assert_equal [ "Rendre à l'enseignant" ], html.css("button.ps-btn--primary").map { it.text.strip }
    assert_equal [ "AsSiGn00000001" ], html.css("input[type=hidden][name=assignment_public_id]").map { it["value"] }
    assert_empty html.css(".ps-result")
    assert_empty html.css("p.ps-error")
  end

  test "après le rendu : « Voir ma correction » et « Refaire l'exercice », sans note ; le bouton refait est « Vérifier ma réponse », sans devoir" do
    copy = Queries::Catalog::PrepareSheetsQuery::Copy.new(session_public_id: "sess1", passed: false)
    html = sheet_html(copy:, assignment_public_id: "AsSiGn00000001")

    assert_equal [ "Vérifier ma réponse" ], html.css("button.ps-btn--primary").map { it.text.strip }
    assert_empty html.css("input[name=assignment_public_id]")
    assert_empty html.css(".ps-result")
    assert_equal [ "Voir ma correction" ], html.css("a.ps-btn--redo").map { it.text.strip }
    assert_equal [ "Refaire l'exercice" ], html.css("button.ps-btn--redo").map { it.text.strip }
  end
end
