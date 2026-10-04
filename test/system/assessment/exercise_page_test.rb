require "application_system_test_case"

# AS-02, AS-39 — UDR-0021. L'élève ouvre un exercice publié : il voit sa progression et les questions sans aucune marque,
# clique « Commencer l'exercice » et arrive sur la première question (Turbo Drive). L'équipe ouvre « Modifier » (menu ⋮) dans la
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
    @exercise = create_exercise(essential: @essential, title: "Méiose", description: "Deux divisions successives.")
  end

  def scope = "assessment.exercises"

  test "l'élève voit sa progression et les questions sans marque, puis « Commencer » l'amène à la première question" do
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours.
    student = create_student_for(@course)
    create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent: 50)
    sign_in_as student

    visit exercise_path(@exercise.public_id)

    within "#exercise_header" do
      assert_selector "h1", text: "Méiose"
      assert_text "Deux divisions successives."
      assert_text I18n.t("#{scope}.show.questions", count: 2)
    end
    within "#student_progress" do
      assert_text "10/20"
      assert_no_text "50 %"
      assert_text "Fragile"
      assert_text I18n.t("#{scope}.student_progress.completed", count: 1)
    end
    assert_selector "#exercise_questions li.question", count: 2
    assert_no_selector "#exercise_questions [data-correct]"
    assert_no_text I18n.t("#{scope}.questions_preview.correct")

    click_on I18n.t("#{scope}.student_progress.start")

    assert_current_path %r{\A/sessions/[^/]+\z}
    assert_text "Question 1"
  end

  test "sur un téléphone, la page de l'élève tient dans la largeur" do
    # UDR-0013, amendement du 2026-10-01 : l'élève est d'une classe du niveau du cours.
    sign_in_as create_student_for(@course)

    with_mobile_viewport do
      visit exercise_path(@exercise.public_id)

      assert_selector "#student_progress button", text: I18n.t("#{scope}.student_progress.start")
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  # UDR-0021, amendement du 2026-10-02 (UDR-0057) : ce que l'accueil retire de ses lignes vit ici (Q4), et la page suit
  # la règle de sobriété à 390 × 844 (R1, R2, R3).
  test "à 390 px, l'élève voit badge, meilleure note, maîtrise et sessions, une seule action principale, 3 questions puis « Voir plus »" do
    exercise = create_exercise(essential: @essential, title: "Mitose", questions: 7)
    student = create_student_for(@course)
    best = create_exercise_session(student:, exercise:, status: "completed", score_percent: 85)
    create_badge(student:, exercise:, level: "gold", session: best)
    create_exercise_session(student:, exercise:)
    sign_in_as student

    with_mobile_viewport do
      visit exercise_path(exercise.public_id)

      assert_selector "#exercise_context", exact_text: "Génétique et évolution"
      within "#student_progress" do
        assert_text I18n.t("#{scope}.student_progress.best_score")
        assert_text "17/20"
        assert_text "Acquis"
        assert_text I18n.t("#{scope}.student_progress.badge_level", level: "Or")
        assert_text I18n.t("#{scope}.student_progress.completed", count: 1)
        assert_link I18n.t("#{scope}.student_progress.resume")
        assert_button I18n.t("#{scope}.student_progress.restart")
        assert_no_text I18n.t("#{scope}.student_progress.restart_hint")
      end
      assert_no_text I18n.t("#{scope}.questions_preview.student_hint")
      assert_single_primary_action
      assert_blocks_above_fold "#exercise_header > *, #main > div > div.space-y-10 > *"
      assert_list_capped "#exercise_questions ol", items: "li.question"

      within "#exercise_questions" do
        assert_no_page_reload { click_on I18n.t("components.reveal.more") }
        assert_selector "li.question", count: 6
        click_on I18n.t("components.reveal.more")
        assert_selector "li.question", count: 7
        assert_no_button I18n.t("components.reveal.more")
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
    end
  end

  test "l'enseignant voit les propositions correctes marquées" do
    sign_in_as create_teacher

    visit exercise_path(@exercise.public_id)

    assert_selector "#exercise_questions [data-correct]", count: 2, text: I18n.t("#{scope}.questions_preview.correct")
    assert_no_selector "#student_progress"
  end

  test "l'enseignant voit l'écran inchangé : contexte complet, aide affichée, toutes les questions, sans « Voir plus »" do
    exercise = create_exercise(essential: @essential, title: "Mitose", questions: 5)
    sign_in_as create_teacher

    visit exercise_path(exercise.public_id)

    assert_selector "#exercise_context", exact_text: I18n.t("#{scope}.show.context", course: "Génétique et évolution",
                                                                                      essential: "La méiose")
    assert_selector "#exercise_questions p", text: I18n.t("#{scope}.questions_preview.reveal_hint")
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
