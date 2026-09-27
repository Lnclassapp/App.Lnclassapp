require "application_system_test_case"

# AS-11, AS-12, AS-13 (UDR-0023) : le résultat d'une session. 10/10 : « Diamant », « Nouveau badge ! » et des confettis
# pendant 3 s ; 9/10 : « Or », jamais Diamant, et « Recommencer » ouvre une nouvelle session (changement de page), l'ancienne
# gardant son score ; sous le seuil : « Courage ! », sans confettis. Sur un bureau comme à 390 px.
class Assessment::SessionResultTest < ApplicationSystemTestCase
  SCOPE = "assessment.session_results".freeze
  GRADING = Entities::Assessment::Grading

  setup do
    @student = create_student(classroom: create_classroom)
    @exercise = create_exercise(title: "Méiose", questions: 10)
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

  test "sous le seuil : « Courage ! », « Non acquis », aucun confetti" do
    session = completed_session(correct: 4)

    visit exercise_session_result_path(session.public_id)

    assert_selector "h1", text: I18n.t("#{SCOPE}.show.headline.error")
    assert_selector "#session_badge[aria-label='#{I18n.t("assessment.badges.levels.none")}']"
    assert_text I18n.t("assessment.badges.mastery.struggling")
    assert_no_selector "#confetti", visible: :all
    assert_button I18n.t("#{SCOPE}.show.restart")
  end

  private

  def badge(level) = I18n.t("#{SCOPE}.badge.label", level:)

  def play_nine_out_of_ten
    session = completed_session(correct: 9)

    visit exercise_session_result_path(session.public_id)

    assert_selector "#session_badge[aria-label='#{badge('Or')}']"
    assert_no_selector "#session_badge[aria-label='#{badge('Diamant')}']"
    assert_text "18/20"
    assert_text "#{GRADING.score_percent(correct: 9, total: 10)} %"
    assert_selector "#session_review li[id^=question_review_]", count: 10

    click_on I18n.t("#{SCOPE}.show.restart")

    assert_current_path %r{\A/sessions/(?!#{session.public_id})[^/]+\z}
    fresh = Orm::ExerciseSession.where(student: @student, exercise: @exercise, status: "started").sole
    assert_current_path exercise_session_path(fresh.public_id)
    assert_equal [ "completed", GRADING.score_percent(correct: 9, total: 10) ], session.reload.values_at(:status, :score_percent)
  end
end
