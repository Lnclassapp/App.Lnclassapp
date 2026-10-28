require "application_system_test_case"

# AS-02, AS-39 — UDR-0138 §3.1. L'élève ouvre un exercice publié : il lit la feuille sans aucune marque,
# clique « Faire l'exercice » et arrive sur sa copie (Turbo Drive). L'équipe ouvre « Modifier » (menu ⋮) dans la
# modale, sans rechargement de page ; l'enseignant voit les propositions correctes marquées.
class Assessment::ExercisePageTest < ApplicationSystemTestCase
  # Les accueils (Lots A2, B6, D3) et la session (Lot C2) appartiennent à d'autres lots : tant qu'ils ne sont pas fusionnés,
  # un remplaçant répond là où la connexion arrive et là où « Commencer » mène. Un contrôleur fusionné se charge seul, le
  # remplaçant s'efface ; les assertions valent pour les deux (une page /sessions/… qui montre la question 1).
  %i[StudentHomesController TeacherHomesController].each do |name|
    next if Object.const_defined?("Classroom::#{name}")

    Classroom.const_set(name, Class.new(AuthenticatedController) { def show = render(html: "home", layout: true) })
  end
  unless Object.const_defined?("Assessment::ExerciseSessionsController")
    Assessment.const_set(:ExerciseSessionsController, Class.new(AuthenticatedController) do
      def create = redirect_to(exercise_session_path("remplacant"), status: :see_other)
      def show = render(html: "Question 1", layout: true)
    end)
  end
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) { def show = render(html: "home", layout: true) })
  end

  setup do
    @course = course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"))
    @essential = create_essential(course:, name: "La méiose")
    @exercise = create_exercise(essential: @essential, title: "Méiose", statement: "Deux divisions successives.")
  end

  def scope = "assessment.exercises"

  # UDR-0138 §3.1 : la page est la feuille ; après une copie rendue, le bouton est « Refaire l'exercice ».
  test "l'élève lit la feuille sans marque, puis « Refaire l'exercice » l'amène à sa copie" do
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours.
    student = create_student_for(@course)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 50)
    sign_in_as student

    visit exercise_path(@exercise.public_id)

    within "#exercise_header" do
      assert_selector "h1", text: "Méiose"
      assert_text I18n.t("#{scope}.show.questions", count: 2)
    end
    assert_selector "#exercise-sheet", text: "Deux divisions successives."
    assert_selector "#exercise_best", text: "10/20"
    assert_selector "#exercise_questions li.question", count: 2
    assert_no_selector "#exercise_questions [data-correct]"
    assert_no_selector "#exercise_questions input"
    assert_no_text I18n.t("#{scope}.questions_preview.correct")

    assert_no_button I18n.t("#{scope}.show.start")
    click_on I18n.t("#{scope}.show.redo")

    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_selector "#copy-form #question-1"
  end

  test "sur un téléphone, la feuille tient dans la largeur et l'action est collée en bas" do
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours.
    sign_in_as create_student_for(@course)

    with_mobile_viewport do
      visit exercise_path(@exercise.public_id)

      assert_selector "#exercise_actions button", text: I18n.t("#{scope}.show.start")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      assert page.evaluate_script("Math.abs(document.querySelector('#exercise_actions').getBoundingClientRect().bottom - window.innerHeight) < 2")
    end
  end

  # UDR-0138 §3.1 : une seule action principale à 390 px, toutes les questions de la feuille lisibles.
  test "à 390 px, une seule action principale et toutes les questions de la feuille" do
    exercise = create_exercise(essential: @essential, title: "Mitose", questions: 7)
    student = create_student_for(@course)
    create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_path(exercise.public_id)

      assert_selector "#exercise_context", exact_text: "La méiose"
      assert_link I18n.t("#{scope}.show.resume")
      assert_button I18n.t("#{scope}.show.restart")
      assert_selector "#exercise_questions li.question", count: 7
      assert_no_button I18n.t("components.reveal.more")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  test "l'enseignant voit la solution sous chaque question" do
    sign_in_as create_teacher

    visit exercise_path(@exercise.public_id)

    assert_selector "#exercise_questions [data-correct]", minimum: 1, text: I18n.t("#{scope}.questions_preview.correct")
    assert_no_selector "#exercise_actions"
  end

  test "l'enseignant voit toutes les questions, sans « Voir plus »" do
    exercise = create_exercise(essential: @essential, title: "Mitose", questions: 5)
    sign_in_as create_teacher

    visit exercise_path(exercise.public_id)

    assert_selector "#exercise_context", exact_text: "La méiose"
    assert_selector "#exercise_questions li.question", count: 5
    assert_no_button I18n.t("components.reveal.more")
  end

  test "l'équipe ouvre « Modifier » dans la modale, sans rechargement de page" do
    sign_in_as create_team_member

    visit exercise_path(@exercise.public_id)

    assert_no_page_reload do
      click_menu_action("#exercise_header", I18n.t("#{scope}.show.edit"))

      assert_selector "turbo-frame#modal dialog[open] #exercise-form"
    end
    assert_field "exercise[title]", with: "Méiose"
  end
end
