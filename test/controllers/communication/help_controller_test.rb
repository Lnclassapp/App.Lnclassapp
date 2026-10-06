require "test_helper"

# UDR-0061 (FAQ, construite directement à la demande du porteur, 2026-10-02) : la page « Questions fréquentes » est
# publique, garde le motif des écrans d'entrée (logo, retour, un seul h1) et tire ses seuils du domaine.
class Communication::HelpControllerTest < ActionDispatch::IntegrationTest
  GRADING = Entities::Assessment::Grading

  test "a visitor reads the FAQ without signing in" do
    get help_path

    assert_response :success
    assert_select "h1", count: 1, text: "Questions fréquentes"
    assert_select "a[href='#{root_path}']", text: /Accueil/
  end

  test "every question is a native disclosure, its answer folded" do
    get help_path

    assert_select "#help_questions details", count: Communication::HelpController::QUESTIONS.size
    assert_select "#help_questions details[open]", 0
    assert_select "#help_questions details > summary", text: "J'ai oublié mon PIN, que faire ?"
  end

  test "the answers quote the thresholds of the domain, not copies of them" do
    get help_path

    assert_select "#help_question_badges", text: /Or à partir de #{GRADING::GOLD_THRESHOLD} %/
    assert_select "#help_question_gaps", text: /au moins #{GRADING::REMEDIATION_THRESHOLD} %/
    assert_select "#help_question_grade", text: /16\/20/
  end

  # UDR-0061 §4, UDR-0062 §4: the due dates lot adds « Que veut dire « En retard » ? » (PRD « FAQ »).
  test "the FAQ explains « En retard »: the due date passed, the exercise stays open" do
    get help_path

    assert_includes Communication::HelpController::QUESTIONS, :late
    assert_select "#help_question_late > summary", text: "Que veut dire « En retard » ?"
    assert_select "#help_question_late p", text: /date limite.*toujours le faire/
  end

  # UDR-0061, amendement du 2026-10-06 : connecté, l'élève lit la FAQ dans son shell, retour vers son accueil.
  test "a signed-in student reads the FAQ in the shell, with a way back to the student home" do
    sign_in_as create_student(classroom: create_classroom)

    get help_path

    assert_response :success
    assert_select "main#main", count: 1
    assert_select "nav", minimum: 2
    assert_select "h1", count: 1, text: "Questions fréquentes"
    assert_select "nav a[href='#{student_home_path}']", text: /Accueil/
    assert_select "a[aria-label='Lnclass, accueil']", 0
    assert_select "#help_questions details", count: Communication::HelpController::QUESTIONS.size
  end

  test "a visitor keeps the entry page: logo, back to the public home, no shell" do
    get help_path

    assert_select "main#main", 0
    assert_select "a[aria-label='Lnclass, accueil'][href='#{root_path}']"
  end

  # ADR-0063 : l'enseignant sans école n'a pas de navigation ; il garde la page d'entrée.
  test "a teacher waiting for a school keeps the entry page" do
    sign_in_as create_user(role: "teacher")

    get help_path

    assert_response :success
    assert_select "main#main", 0
    assert_select "a[aria-label='Lnclass, accueil']"
  end

  # UDR-0061, amendement du 2026-10-06 : les liens « Vos données » faisaient 18 px de haut.
  test "every link of « Vos données » is a 48 px target" do
    get help_path

    assert_select "#help_your_data a", count: 2
    assert_select "#help_your_data a:not(.min-h-tap)", 0
  end

  test "the student home offers « Besoin d'aide ? », which leads to the FAQ" do
    sign_in_as create_student(classroom: create_classroom)

    get student_home_path

    assert_select "a[href='#{help_path}']", text: "Besoin d'aide ?"
  end
end
