require "application_system_test_case"

# Chantier progres-eleve, phase 5 — challenger empirique (PRD §3 et §4, UDR-0073), dans un navigateur réel.
# 1. Le parcours du PRD, tout dans l'interface : l'élève fait l'exercice avec peu de bonnes réponses (1 sur 3), le
#    recommence avec toutes (3 sur 3), et lit « Tu progresses ». Rouge tant que le défaut D1 du rapport du challenger
#    (journal.md) n'est pas tranché : sous 50 %, une lacune s'ouvre, et la session suivante est une remédiation, que
#    l'UDR-0073 §3 exclut de l'historique ; la phrase ne vient jamais.
# 2. Un parcours sans lacune : une première session à 10/20, puis une session faite dans l'interface (2 sur 3) ;
#    « Tu progresses », puis, après une session ratée, « Ton meilleur résultat reste » ; le deuxième résultat rouvert dit
#    encore « Tu progresses », lisible en mode sombre et sans défilement horizontal au téléphone. Rien au premier essai
#    d'un autre exercice, rien pour l'enseignant de la classe ; jamais « stagne », « baisse » ni « essai ».
class Assessment::StudentProgressTest < ApplicationSystemTestCase
  RESULTS = "assessment.session_results".freeze
  SESSIONS = "assessment.exercise_sessions".freeze
  QUESTIONS = 3
  FORBIDDEN = /stagne|baisse|essai/i
  SENTENCES = %w[progress stable stagnant decline].freeze
  # WCAG AA pour un texte de 14 px (text-sm).
  AA_CONTRAST = 4.5
  # « Recommencer » : le POST puis la page de la session, sous une suite chargée (session_result_test.rb).
  RESTART_WAIT = 10

  setup do
    course = create_course
    @classroom = create_classroom(level: course.level, series: course.series)
    @student = create_student(classroom: @classroom)
    @exercise = create_exercise(essential: create_essential(course:), title: "Méiose", questions: QUESTIONS)
    sign_in_as @student
    assert_current_path student_home_path
  end

  test "le parcours du PRD dans l'interface : peu de bonnes réponses, puis toutes ; l'élève lit « Tu progresses »" do
    visit exercise_path(@exercise.public_id)
    click_on I18n.t("assessment.exercises.student_progress.start")
    play(correct: 1)
    assert_text "7/20"
    assert_no_progress_sentence

    click_on I18n.t("#{RESULTS}.show.restart")
    play(correct: 3)
    assert_text "20/20"
    assert_progress_sentence I18n.t("#{RESULTS}.progress.progress", first: 7, current: 20)
  end

  test "sans lacune : « Tu progresses », puis « Ton meilleur résultat reste » ; rien ailleurs ni pour l'enseignant" do
    teacher = create_teacher(classrooms: [ @classroom ])
    completed(@exercise, 50)

    visit exercise_path(@exercise.public_id)
    click_on I18n.t("assessment.exercises.student_progress.start")
    second = play(correct: 2)
    assert_text "13/20"
    assert_progress_sentence I18n.t("#{RESULTS}.progress.progress", first: 10, current: 13)

    visit exercise_session_result_path(completed(@exercise, 25).public_id)
    assert_progress_sentence I18n.t("#{RESULTS}.progress.decline", best: 13)

    visit exercise_session_result_path(second)
    assert_progress_sentence I18n.t("#{RESULTS}.progress.progress", first: 10, current: 13)
    assert_readable_in_dark_mode
    assert_fits_a_phone

    other = create_exercise(essential: @exercise.essential, title: "Mitose", questions: QUESTIONS)
    visit exercise_session_result_path(completed(other, 75).public_id)
    assert_text "15/20"
    assert_no_progress_sentence

    sign_out
    sign_in_as teacher
    visit exercise_session_result_path(second)
    assert_text I18n.t("#{RESULTS}.show.student", name: "#{@student.first_name} #{@student.last_name}")
    assert_text "13/20"
    assert_no_progress_sentence
  end

  private

  def completed(exercise, score_percent)
    create_exercise_session(student: @student, exercise:, status: "completed", score_percent:)
  end

  # Répond aux questions de la session ouverte, dans l'interface : les `correct` premières justes (la proposition 1 est
  # la bonne, fabrique create_exercise), les autres fausses ; puis « Voir mon résultat ». → public_id de la session.
  def play(correct:)
    assert_current_path %r{\A/sessions/[^/]+\z}, wait: RESTART_WAIT
    public_id = current_path.split("/").last
    QUESTIONS.times do |index|
      within("#question-card", text: "Question #{index + 1}") { choose(index < correct ? "Proposition 1" : "Proposition 2") }
      click_on I18n.t("#{SESSIONS}.question_card.submit")
      assert_selector "#feedback-card"
      click_on I18n.t("#{SESSIONS}.feedback_card.#{index == QUESTIONS - 1 ? 'result' : 'next'}")
    end
    assert_current_path exercise_session_result_path(public_id)
    public_id
  end

  def assert_progress_sentence(sentence)
    assert_selector "#session_result #session_progress", exact_text: sentence
    assert_no_forbidden_words
  end

  def assert_no_progress_sentence
    assert_selector "#session_result dl"
    assert_no_selector "#session_progress"
    SENTENCES.each { assert_no_text I18n.t("#{RESULTS}.progress.#{it}").split("%{").first }
    assert_no_forbidden_words
  end

  # La page entière, texte visible comme caché (sr-only), et son titre : aucun mot de sanction ni « essai ».
  def assert_no_forbidden_words
    assert_no_text :all, FORBIDDEN
    assert_no_match FORBIDDEN, page.title
  end

  def assert_readable_in_dark_mode
    page.execute_script("document.documentElement.dataset.theme = 'dark'")
    assert_selector "html[data-theme=dark]"
    assert_equal "rgb(15, 18, 24)", page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    ratio = contrast_ratio(find("#session_progress span"))
    assert_operator ratio, :>=, AA_CONTRAST, "phrase de progrès illisible en mode sombre : contraste #{ratio.round(2)}:1"
  ensure
    page.execute_script("document.documentElement.dataset.theme = 'light'")
  end

  def assert_fits_a_phone
    with_mobile_viewport do
      assert_selector "#session_progress"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page de résultat déborde en largeur"
    end
  end

  # Contraste WCAG entre la couleur du texte et le premier fond opaque de ses ancêtres. Les couleurs des tokens (oklch)
  # passent par un canvas d'un pixel pour être lues en sRGB.
  def contrast_ratio(element)
    page.evaluate_script(<<~JS, element.native)
      (() => {
        const rgba = (css) => {
          const context = Object.assign(document.createElement("canvas"), { width: 1, height: 1 }).getContext("2d")
          context.fillStyle = css
          context.fillRect(0, 0, 1, 1)
          return [ ...context.getImageData(0, 0, 1, 1).data ]
        }
        const luminance = ([ r, g, b ]) => {
          const channel = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4 }
          return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }
        let node = arguments[0], back = null
        while (node && !back) {
          const color = rgba(getComputedStyle(node).backgroundColor)
          if (color[3] === 255) back = color
          node = node.parentElement
        }
        const [ light, dark ] = [ luminance(rgba(getComputedStyle(arguments[0]).color)), luminance(back) ].sort((a, b) => b - a)
        return (light + 0.05) / (dark + 0.05)
      })()
    JS
  end
end
