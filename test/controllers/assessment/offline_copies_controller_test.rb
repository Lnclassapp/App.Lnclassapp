require "test_helper"

# CA-7 (page) — hors-connexion Lot B (ADR §4.4, UDR §3.3 et §3.4) : la copie hors ligne est la feuille de la copie en ligne, sans session,
# sans indice et sans aucune bonne réponse dans le HTML ; gardable (Lnclass-Offline: keep).
class Assessment::OfflineCopiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    course = create_course(level: create_level(name: "Tle"), series: create_series(name: "D"), material: create_material(name: "SVT", category: "science"))
    @exercise = create_exercise(essential: create_essential(course:), questions: 1, statement: "Un sujet.", hint: nil)
    @exercise.questions.first.update!(explanation: "Explication secrète.", hint: "Un indice secret")
    @numeric = create_kind_question(exercise: @exercise, question_type: "numeric", answers: [ "4.8" ], content: "Mesure ?", numeric_tolerance: "0.5", explanation: "Valeur 4.8")
    @ordering = create_kind_question(exercise: @exercise, question_type: "ordering", answers: %w[Premier Deuxième Troisième], content: "Ordonne")
    @matching = create_kind_question(exercise: @exercise, question_type: "matching", answers: [ %w[Gauche1 Droite1], %w[Gauche2 Droite2], %w[Gauche3 Droite3] ], content: "Relie")
    @select = create_kind_question(exercise: @exercise, question_type: "select", answers: [ "rouge" ], content: "Le ciel est ___.")
    @select.answers.create!(position: 2, content: "bleu", correct: false)
    @fill = create_kind_question(exercise: @exercise, question_type: "fill_blank", answers: [ "Abidjan" ], content: "Capitale : ___")
    @written = create_kind_question(exercise: @exercise, question_type: "written", answers: [], content: "Explique", explanation: "Corrigé type rédigé")
    @student = create_student_for(course)
  end

  test "l'élève reçoit la copie : sujet, questions, formulaire hors ligne sans action, pied et lien de retour" do
    sign_in_as @student

    get offline_copy_exercise_path(@exercise.public_id)

    assert_response :success
    assert_select "#copy-sheet"
    assert_select "#copy-statement", text: /Un sujet\./
    assert_select "form#copy-form[data-controller='offline-copy'][data-offline-copy-exercise-value='#{@exercise.public_id}']"
    assert_select "form#copy-form[action]", 0
    assert_select "#copy-form li[id^='question-']", 7
    assert_select "#copy-form input[type=radio], #copy-form input[type=checkbox]", 4
    assert_select "#copy-form input[name$='[response_text]'], #copy-form textarea[name$='[response_text]']", 3
    assert_select "#copy-form select[name$='[display_order][]']", 7
    assert_select "p.mb-3.text-sm.text-mute", text: I18n.t("offline.copy.footer")
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']"
    assert_select "template[data-offline-copy-target='result'] section#offline_result"
  end

  test "la page ne porte aucune bonne réponse, aucune explication, aucun indice ni aucun identifiant de proposition" do
    sign_in_as @student

    get offline_copy_exercise_path(@exercise.public_id)

    body = response.body
    assert_no_match(/Explication secrète|Corrigé type rédigé|Valeur 4\.8|Un indice secret/, body)
    assert_select "button", text: I18n.t("assessment.exercise_sessions.show.hint_button"), count: 0
    assert_select "[data-correct]", 0
    Orm::Answer.where(question: @exercise.questions).pluck(:id).each { |id| assert_no_match(/answer_#{id}\b|value="#{id}"/, body) }
    assert_select "input[checked]", 0
  end

  test "la page est gardable hors ligne et ne s'écrit rien : aucune session n'est ouverte" do
    sign_in_as @student

    assert_no_difference -> { Orm::ExerciseSession.count } do
      get offline_copy_exercise_path(@exercise.public_id)
    end

    assert_equal "keep", response.headers["Lnclass-Offline"]
  end

  test "un enseignant est refusé et la page n'est pas gardée" do
    sign_in_as create_teacher

    get offline_copy_exercise_path(@exercise.public_id)

    assert_response :forbidden
    assert_nil response.headers["Lnclass-Offline"]
  end

  test "un visiteur est renvoyé à la connexion, sans garder la page" do
    get offline_copy_exercise_path(@exercise.public_id)

    assert_not response.successful?
    assert_nil response.headers["Lnclass-Offline"]
  end

  test "un élève d'un autre niveau, un exercice non publié, un exercice inconnu : 404" do
    other = create_student_for(create_course(level: create_level(name: "6e"), series: create_series(name: "A"), material: create_material(name: "Maths", category: "science")))
    sign_in_as other
    get offline_copy_exercise_path(@exercise.public_id)
    assert_response :not_found

    sign_in_as @student
    get offline_copy_exercise_path("inconnu")
    assert_response :not_found

    @exercise.update!(status: "draft")
    get offline_copy_exercise_path(@exercise.public_id)
    assert_response :not_found
  end

  test "un accès bloqué mène à Mon abonnement" do
    close_beta_for_this_test
    travel_to 30.days.from_now do
      sign_in_as @student
      get offline_copy_exercise_path(@exercise.public_id)
    end

    assert_redirected_to billing_subscription_path
  end

  test "le bouton « Commencer » du sujet porte offline-start : paquet, copie hors ligne et message" do
    sign_in_as @student

    get exercise_path(@exercise.public_id)

    assert_select "form#start-exercise-form[data-controller='offline-start'][data-offline-start-pack-url-value='#{offline_pack_exercise_path(@exercise.public_id)}']" \
                  "[data-offline-start-copy-url-value='#{offline_copy_exercise_path(@exercise.public_id)}']" do
      assert_select "button[type=submit][data-offline-start-target=button]", text: I18n.t("assessment.exercises.show.start")
      assert_select "p#offline-start-unavailable[hidden][data-offline-start-target=unavailable]", text: I18n.t("offline.start.unavailable")
    end
  end

  test "le bouton « Refaire » porte aussi offline-start, un enseignant n'en voit aucun" do
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent: 50)
    sign_in_as @student
    get exercise_path(@exercise.public_id)
    assert_select "form#start-exercise-form[data-controller='offline-start'] button[data-offline-start-target=button]", text: I18n.t("assessment.exercises.show.redo")

    sign_in_as create_teacher
    get exercise_path(@exercise.public_id)
    assert_select "[data-controller='offline-start']", 0
  end
end
