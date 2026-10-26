require "application_system_test_case"

# Lot K de mvp-teacher-student — CA-I4, CA-I5, UDR enseignant §3.8, ADR-0079. Dans un navigateur réel, l'enseignant ouvre le
# rapport d'un exercice, lit « 10 / 13 faits » et les cinq cases par badge, touche « Bronze » : la liste des élèves se filtre
# dans le Turbo Frame (taux par question, « À reprendre en classe », « 1re session : … », élèves en baisse d'abord). Le badge
# vit dans l'adresse et survit au rechargement ; les élèves pas encore faits sont nommés. Un élève qui force l'adresse : 403.
class Classroom::ComprehensionTest < ApplicationSystemTestCase
  NBSP = " ".freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, level: create_level(name: "Tle"), series: create_series(name: "D"), name: "Tle D 1")
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    @exercise = create_exercise(title: "Phases de la mitose", questions: 3)
    @questions = @exercise.questions.order(:position).to_a
    @assignment = create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher)
    @clock = 3.days.ago

    # Bronze (meilleur score de 50 à 69) : un élève par signe, nommés pour que l'ordre alphabétique contredise celui des signes.
    # Questions au meilleur essai : Q1 juste, Q2 juste, Q3 fausse pour les quatre → 100 %, 100 %, 0 % (« À reprendre »).
    # Au premier essai, Q2 est fausse pour Sylla et Adou → « 1re session : 50 % ». Les trois 60 de Sylla : le plus récent
    # compte (ADR-0079 §4.5) ; si c'était le premier, Q3 ne serait pas à 0 %.
    done "Paul", "Zadi", [ 65, [ true, true, false ] ], [ 50, [ true, false, false ] ]                  # en baisse
    done "Fanta", "Sylla", [ 60, [ true, false, true ] ], [ 60, [ true, false, true ] ], [ 60, [ true, true, false ] ] # stagne
    done "Aya", "Konan", [ 67, [ true, true, false ] ]                                                 # 1 session
    done "Bakary", "Adou", [ 50, [ true, false, false ] ], [ 60, [ true, true, false ] ]                # en progrès
    # Argent, Or, Diamant (dominante, 5 élèves), avec les séries du PRD : 30-60-90, 100-100, 80-90-81.
    done "Mariam", "Bamba", [ 30 ], [ 60 ], [ 90 ]
    done "Koffi", "Yao", [ 100 ], [ 100 ]
    done "Ange", "Kouadio", [ 80 ], [ 90 ], [ 81 ]
    done "Salif", "Traoré", [ 75 ]
    done "Rokia", "Cissé", [ 85 ]
    # Pas encore (sous 50).
    done "Yves", "Gnagne", [ 40 ]
    # Pas encore faits : deux élèves sans session, un élève à session seulement commencée.
    create_student(classroom: @classroom, first_name: "Zoé", last_name: "Abo")
    create_student(classroom: @classroom, first_name: "Marc", last_name: "Touré")
    started = create_student(classroom: @classroom, first_name: "Ibrahim", last_name: "Diallo")
    create_exercise_session(student: started, exercise: @exercise, status: "started", classroom_assignment: @assignment)
  end

  test "l'enseignant lit « 10 / 13 faits » et cinq cases, filtre sur Bronze, recharge, et voit qui n'a pas encore fait" do
    sign_in_as @teacher
    visit classroom_assignment_path(@classroom.public_id, @assignment.public_id)

    within "#comprehension" do
      assert_selector "h2", text: "Compréhension"
      assert_text "10 / 13 faits"
      assert_no_selector "span.size-14"
      # Signes : progrès = Adou, Bamba, Kouadio ; sans évolution = Sylla, Yao ; baisse = Zadi ; sans signe : les 4 autres.
      assert_selector "#comprehension_trends", text: "3 en progrès · 2 sans évolution · 1 en baisse"
      { "Pas encore" => 1, "Bronze" => 4, "Argent" => 1, "Or" => 3, "Diamant" => 1 }.each { |label, count| assert_box label, count }
      assert_selector "nav a[aria-current=true]", count: 0

      find("nav a", text: "Bronze").click

      assert_selector "nav a[aria-current=true]", count: 1, text: "Bronze"
    end
    assert_bronze_panel
    assert_current_path classroom_assignment_path(@classroom.public_id, @assignment.public_id, badge: "bronze")

    page.driver.browser.navigate.refresh

    assert_current_path classroom_assignment_path(@classroom.public_id, @assignment.public_id, badge: "bronze")
    assert_selector "#comprehension nav a[aria-current=true]", count: 1, text: "Bronze"
    assert_bronze_panel

    within "#pending_students" do
      assert_selector "h2", text: "Pas encore faits · 3"
      assert_equal [ "Zoé Abo", "Ibrahim Diallo", "Marc Touré" ], all("li").map(&:text)
    end
    assert_no_text(/\bessais?\b/i)

    # CA-I5 : lecture fiable, dominante Argent ou mieux, Paul Zadi en baisse ; le geste parle en badges.
    assert_selector "#comprehension_next_step", text: /Prochain geste\s+La classe a atteint l'Argent ou mieux\. Un élève est en baisse/i
    assert_no_text(/En difficulté|Fragile|Acquis/)
    # UDR-0109 §3.1 : un nom de la liste ouvre la fiche en page entière, hors du cadre des cases.
    within("#comprehension_panel") { click_on "Paul Zadi" }
    paul = Orm::User.find_by!(first_name: "Paul", last_name: "Zadi")
    assert_current_path classroom_student_path(@classroom.public_id, paul.public_id)
    assert_selector "h1", text: "Paul Zadi"
    assert_no_selector "turbo-frame#comprehension_frame"
  end

  test "un élève de la classe qui force l'adresse du suivi est refusé (403)" do
    student = Orm::User.find_by!(first_name: "Paul", last_name: "Zadi")
    sign_in_as student
    url = classroom_assignment_path(@classroom.public_id, @assignment.public_id, badge: "bronze")

    # Le navigateur ne montre pas le statut : il le lit par un fetch de même origine, avec le cookie de l'élève.
    assert_equal 403, page.evaluate_async_script("fetch(arguments[0]).then(r => arguments[1](r.status))", url)
    visit url
    assert_text I18n.t("errors.forbidden.title")
    assert_no_selector "#comprehension"
    assert_no_text "Fanta Sylla"
    assert_no_text "Zoé Abo"
  end

  private

  # Un élève présent de la classe et ses sessions faites de l'assignation, dans l'ordre ; chaque session : [score, réponses].
  def done(first_name, last_name, *sessions)
    student = create_student(classroom: @classroom, first_name:, last_name:)
    sessions.each do |score_percent, answers|
      @clock += 1.minute
      session = create_exercise_session(student:, exercise: @exercise, status: "completed", score_percent:,
                                        classroom_assignment: @assignment, completed_at: @clock)
      Array(answers).each_with_index { |correct, index| create_attempt(session:, question: @questions[index], correct:) }
    end
  end

  def assert_box(label, count)
    assert_selector "nav[aria-label='Élèves par badge'] a", text: /\A#{count}\s+#{label}\s/
  end

  def assert_bronze_panel
    within "#comprehension_questions" do
      assert_selector "li[aria-label='Question 1 : 100#{NBSP}% de réussite']"
      assert_selector "li[aria-label='Question 2 : 100#{NBSP}% de réussite, 50#{NBSP}% à la première session']",
                      text: "1re session : 50 %"
      # Q3 : juste à la 1re session de Sylla seule (25 %), fausse au meilleur essai de tous (0 %) : la classe a régressé.
      assert_selector "li[aria-label='Question 3 : 0#{NBSP}% de réussite, 25#{NBSP}% à la première session, à reprendre en classe']",
                      text: "À reprendre en classe"
      assert_selector "ol li", text: "À reprendre en classe", count: 1
    end
    within "#comprehension_panel" do
      # rapports-de-classe, Lot C (UDR-0109 §3.1) : chaque nom est le lien vers la fiche de l'élève.
      students = all("ul li").map { it.find("a").text }
      assert_equal [ "Paul Zadi", "Fanta Sylla", "Aya Konan", "Bakary Adou" ], students
      assert_selector "ul li", text: /Paul Zadi\s+65 %\s+En baisse/
      assert_selector "ul li", text: /Aya Konan\s+67 %\s+1 session/
    end
  end
end
