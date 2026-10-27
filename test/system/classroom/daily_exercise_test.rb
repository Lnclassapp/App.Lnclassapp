require "application_system_test_case"

# PRD accueil-eleve CA-8, CA-10, CA-18 (ADR-0089 §4.1, §4.3 · UDR-0084 §3.6) : sans travail de l'enseignant, la carte de l'accueil
# propose l'exercice du jour et « Invite-le » ; « Commencer » démarre la session, et au retour la carte dit
# « Reviens demain ! » avec la matière de demain. CA-11 (priorité stricte) se joue au niveau contrôleur
# (test/controllers/classroom/student_homes_controller_test.rb), hors du budget système (ADR-0069 §9).
class Classroom::DailyExerciseTest < ApplicationSystemTestCase
  SCOPE = "classroom.student_homes".freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "6e"), name: "6e A")
    @student = create_student(classroom: @classroom)
    exercises = [ "Mathématiques", "SVT" ].to_h do |name|
      course = create_course(material: create_material(name:), level: @classroom.level)
      [ name, create_exercise(essential: create_essential(course:), title: "Exercice de #{name}", questions: 1) ]
    end
    # Le tour du jour, calculé comme la query (ADR-0089 §4.1 étape 3) : le test passe quel que soit le jour.
    today = Entities::Assessment::DailyRotation.subject_for(day: Time.zone.today, subjects: %w[mathematiques svt],
                                                            with_candidates: %w[mathematiques svt])
    @today, @tomorrow = today == "svt" ? %w[SVT Mathématiques] : %w[Mathématiques SVT]
    @exercise = exercises.fetch(@today)
  end

  def tl(key, **) = I18n.t("#{SCOPE}.#{key}", **)

  test "CA-8, CA-18, CA-10: the exercise of the day, the invitation, then « Commencer » to « Bravo, à demain ! »" do
    sign_in_as @student

    within("#student_next_step[data-state=unassigned]") do
      assert_text "#{tl("next_step.unassigned.badge")} · Lnclass"
      assert_text @today
      assert_selector "#student_next_step_title", text: @exercise.title
    end
    within("#student_next_step") do
      invite = find_link(tl("next_step.unassigned.invite"))
      assert_equal [ "_blank", "noopener" ], [ invite[:target], invite[:rel] ]
      message = CGI.unescape(invite[:href].delete_prefix("https://wa.me/?text="))
      [ "6e A", "Lycée Classique d'Abidjan", new_teacher_registration_path ].each { assert_includes message, it }
    end

    within("#student_next_step_daily") { click_on tl("next_step.unassigned.start") }
    choose @exercise.questions.first.answers.find_by!(correct: true).content
    click_on I18n.t("assessment.exercise_sessions.question_card.submit")
    assert_link I18n.t("assessment.exercise_sessions.feedback_card.result")

    visit student_home_path
    within("#student_next_step_daily[aria-live='polite']") do
      assert_text tl("next_step.unassigned.done_today")
      assert_text tl("next_step.unassigned.tomorrow", subject: @tomorrow)
    end
    assert_no_button tl("next_step.unassigned.start")
    assert_selector "#student_next_step_invite"
  end
end
