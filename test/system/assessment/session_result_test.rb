require "application_system_test_case"

# AS-11, AS-12, AS-13 (UDR-0023) : le résultat d'une session. 10/10 : « Diamant », « Nouveau badge ! » et des confettis
# pendant 3 s ; 9/10 : « Or », jamais Diamant, et « Recommencer » ouvre une nouvelle session (changement de page), l'ancienne
# gardant son score ; sous le seuil : « Courage ! », sans confettis. Sur un bureau comme à 390 px.
class Assessment::SessionResultTest < ApplicationSystemTestCase
  SCOPE = "assessment.session_results".freeze
  GRADING = Entities::Assessment::Grading
  # « Recommencer » : le POST puis la page de la session, sous une suite chargée ; au-delà, la page n'a vraiment pas changé.
  RESTART_WAIT = 10

  setup do
    @exercise = create_exercise(title: "Méiose", questions: 10)
    # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est du niveau du cours de l'exercice.
    @student = create_student_for(@exercise.essential.course)
    sign_in_as @student
    assert_current_path student_home_path
  end

  # correct : nombre de bonnes réponses sur les 10 questions ; le score est celui que Grading en tire.
  def completed_session(correct:)
    score_percent = GRADING.score_percent(correct:, total: 10)
    create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent:).tap do |session|
      @exercise.questions.order(:position).each_with_index do |question, index|
        create_attempt(session:, question:, correct: index < correct)
      end
      level = GRADING.badge_for(score_percent)
      create_badge(student: @student, exercise: @exercise, level: level.to_s, session:) if level
    end
  end

  test "10/10 : Diamant, « Nouveau badge ! », confettis pendant 3 secondes, et plus de « Recommencer »" do
    session = completed_session(correct: 10)

    visit exercise_session_result_path(session.public_id)

    assert_selector "h1", text: I18n.t("#{SCOPE}.show.headline.success")
    assert_selector "#session_badge[aria-label='#{badge('Diamant')}']", text: I18n.t("#{SCOPE}.badge.new")
    assert_text "20/20"
    assert_selector "#confetti span", visible: :all
    assert_no_selector "#confetti", visible: :all, wait: 8
    assert_no_button I18n.t("#{SCOPE}.show.restart")
  end

  test "9/10 : Or, jamais Diamant ; « Recommencer » ouvre une nouvelle session" do
    play_nine_out_of_ten
  end

  test "le même parcours sur un écran de 390 px" do
    with_mobile_viewport { play_nine_out_of_ten }
  end

  # Chantier tests-instables : « Recommencer » coûte deux allers-retours (le POST, puis la session vers laquelle il
  # redirige). Sous une suite chargée, ils dépassaient les 2 s d'attente par défaut de Capybara.
  test "« Recommencer » ouvre une nouvelle session même quand le serveur répond lentement" do
    on_a_slow_network { play_nine_out_of_ten }
  end

  # UDR-0023, amendement du 2026-10-02 (UDR-0057) : à 390 × 844, la note sur 20 seule, une seule action principale,
  # au plus 5 blocs avant le pli, et 3 cartes de correction puis « Voir plus », par 3.
  test "à 390 px, l'élève lit sa note seule et 3 cartes de correction, puis « Voir plus »" do
    session = completed_session(correct: 9)

    with_mobile_viewport do
      visit exercise_session_result_path(session.public_id)

      within "#session_result dl" do
        assert_selector "dt", count: 2
        assert_text "18/20"
        assert_no_text "#{GRADING.score_percent(correct: 9, total: 10)} %"
        assert_no_text I18n.t("#{SCOPE}.show.correct")
      end
      assert_no_text I18n.t("#{SCOPE}.show.review_hint_student")
      assert_single_primary_action
      assert_blocks_above_fold "#main .max-w-2xl > *"
      assert_list_capped "#session_review ol", items: "li[id^=question_review_]"

      within "#session_review" do
        assert_no_page_reload { click_on I18n.t("components.reveal.more") }
        assert_selector "li[id^=question_review_]", count: 6
        click_on I18n.t("components.reveal.more")
        click_on I18n.t("components.reveal.more")
        assert_selector "li[id^=question_review_]", count: 10
        assert_no_button I18n.t("components.reveal.more")
      end
    end
  end

  test "l'équipe voit le résultat inchangé : score, questions justes, aide et toutes les cartes" do
    session = completed_session(correct: 9)
    sign_out
    sign_in_as create_team_member

    visit exercise_session_result_path(session.public_id)

    within "#session_result dl" do
      assert_selector "dt", count: 4
      assert_text "18/20"
      assert_text "#{GRADING.score_percent(correct: 9, total: 10)} %"
      assert_text I18n.t("#{SCOPE}.show.correct_value", count: 9, total: 10)
    end
    assert_text I18n.t("#{SCOPE}.show.review_hint_reveal")
    assert_selector "#session_review li[id^=question_review_]", count: 10
    assert_no_button I18n.t("components.reveal.more")
  end

  test "sous le seuil : « Courage ! », « Pas encore de badge », aucun confetti" do
    session = completed_session(correct: 4)

    visit exercise_session_result_path(session.public_id)

    assert_selector "h1", text: I18n.t("#{SCOPE}.show.headline.error")
    assert_selector "#session_badge[aria-label='#{I18n.t("#{SCOPE}.badge.none")}']"
    assert_text I18n.t("assessment.badges.mastery.struggling")
    assert_no_selector "#confetti", visible: :all
    assert_button I18n.t("#{SCOPE}.show.restart")
  end

  # UDR-0054, amendement « survol » ; chantier infobulle-badges-hors-ecran. #session_badge est animé (animate-slide-up) :
  # si l'animation garde un transform, il devient le repère de la bulle fixe, qui part loin de l'icône et sort de l'écran.
  test "sur ordinateur, la bulle des badges s'ouvre au survol sous l'icône, dans la fenêtre" do
    visit exercise_session_result_path(completed_session(correct: 9).public_id)
    assert_selector "#session_badge[aria-label='#{badge('Or')}']"
    wait_for_animations("session_badge")

    find("#session_badge summary").hover
    assert_selector "#session_badge details[open]"

    page.document.synchronize do
      icon, panel, width = page.evaluate_script(<<~JS)
        (() => {
          const box = el => { const r = el.getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, bottom: r.bottom } }
          return [ box(document.querySelector("#session_badge summary")), box(document.querySelector("#session_badge [data-info-tip-target=panel]")), innerWidth ]
        })()
      JS
      assert_in_delta icon["left"], panel["left"], 1, "la bulle n'est pas alignée sur le bord gauche de l'icône"
      assert_in_delta icon["bottom"] + 4, panel["top"], 1, "la bulle ne commence pas juste sous l'icône"
      assert_operator panel["right"], :<=, width - 16, "la bulle sort de la fenêtre"
    end
  end

  private

  # Attend la fin des animations d'entrée de l'élément (0,3 s, motion-safe) avant toute mesure.
  def wait_for_animations(id)
    page.document.synchronize do
      done = page.evaluate_script("document.getElementById('#{id}').getAnimations().every(a => a.playState === 'finished')")
      raise Capybara::ExpectationNotMet, "#{id} s'anime encore" unless done
    end
  end

  def badge(level) = I18n.t("#{SCOPE}.badge.label", level:)

  def play_nine_out_of_ten
    session = completed_session(correct: 9)

    visit exercise_session_result_path(session.public_id)

    assert_selector "#session_badge[aria-label='#{badge('Or')}']"
    assert_no_selector "#session_badge[aria-label='#{badge('Diamant')}']"
    assert_text "18/20"
    assert_selector "#session_review li[id^=question_review_]", count: 3

    click_on I18n.t("#{SCOPE}.show.restart")

    assert_current_path %r{\A/sessions/(?!#{session.public_id})[^/]+\z}, wait: RESTART_WAIT
    fresh = Orm::ExerciseSession.where(student: @student, exercise: @exercise, status: "started").sole
    assert_current_path exercise_session_path(fresh.public_id)
    assert_equal [ "completed", GRADING.score_percent(correct: 9, total: 10) ], session.reload.values_at(:status, :score_percent)
  end
end
