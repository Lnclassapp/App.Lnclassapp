require "application_system_test_case"

# Lot C de rapports-exercices — PRD §3 et §4, UDR-0072 §3.4 à §3.8, ADR-0079. Dans un navigateur réel, l'enseignant lit
# au bord bas d'un exercice assigné les badges à gauche et le cercle à droite, ouvre le suivi, choisit « Fragile » :
# taux par question, « À reprendre en classe », « 1re session : … », élèves en baisse d'abord. La catégorie vit dans
# l'adresse et survit au rechargement ; les élèves pas encore faits sont nommés. Un élève qui force l'adresse : 403.
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

    # Fragile (meilleur score de 50 à 69) : un élève par signe, nommés pour que l'ordre alphabétique contredise celui des signes.
    # Questions au meilleur essai : Q1 juste, Q2 juste, Q3 fausse pour les quatre → 100 %, 100 %, 0 % (« À reprendre »).
    # Au premier essai, Q2 est fausse pour Sylla et Adou → « 1re session : 50 % ». Les trois 60 de Sylla : le plus récent
    # compte (ADR-0079 §4.5) ; si c'était le premier, Q3 ne serait pas à 0 %.
    done "Paul", "Zadi", [ 65, [ true, true, false ] ], [ 50, [ true, false, false ] ]                  # en baisse
    done "Fanta", "Sylla", [ 60, [ true, false, true ] ], [ 60, [ true, false, true ] ], [ 60, [ true, true, false ] ] # stagne
    done "Aya", "Konan", [ 67, [ true, true, false ] ]                                                 # 1 session
    done "Bakary", "Adou", [ 50, [ true, false, false ] ], [ 60, [ true, true, false ] ]                # en progrès
    # Acquis (dominante, 5 élèves), avec les séries du PRD : 30-60-90, 100-100, 80-90-81.
    done "Mariam", "Bamba", [ 30 ], [ 60 ], [ 90 ]
    done "Koffi", "Yao", [ 100 ], [ 100 ]
    done "Ange", "Kouadio", [ 80 ], [ 90 ], [ 81 ]
    done "Salif", "Traoré", [ 75 ]
    done "Rokia", "Cissé", [ 85 ]
    # En difficulté.
    done "Yves", "Gnagne", [ 40 ]
    # Pas encore faits : deux élèves sans session, un élève à session seulement commencée.
    create_student(classroom: @classroom, first_name: "Zoé", last_name: "Abo")
    create_student(classroom: @classroom, first_name: "Marc", last_name: "Touré")
    started = create_student(classroom: @classroom, first_name: "Ibrahim", last_name: "Diallo")
    create_exercise_session(student: started, exercise: @exercise, status: "started", classroom_assignment: @assignment)
  end

  test "l'enseignant lit badges et cercle, ouvre le suivi, choisit « Fragile », recharge, et voit qui n'a pas encore fait" do
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)

    within "#assignment_#{@assignment.public_id}" do
      assert_text "10 faits · 3 pas encore faits"
      badges = find("ul[aria-label='Badges de la classe']")
      # 10 meilleurs scores : 65, 60, 67, 60 (Bronze) ; 75 (Argent) ; 90, 90, 85 (Or) ; 100 (Diamant) ; 40 (aucun palier).
      [ "4 Bronze", "1 Argent", "3 Or", "1 Diamant" ].each { assert_selector "li .sr-only", text: it, visible: :all }
      assert_selector "span.rounded-full.bg-success[aria-hidden=true]"
      assert_text "Acquis · 10/13"
      footer = badges.find(:xpath, "..")
      layout = page.evaluate_script(<<~JS, footer.native, badges.native)
        (() => {
          const [footer, badges] = arguments, circle = footer.lastElementChild
          const f = footer.getBoundingClientRect(), b = badges.getBoundingClientRect(), c = circle.getBoundingClientRect()
          return { badgesLeft: b.left - f.left, circleRight: f.right - c.right, badgesBeforeCircle: b.right <= c.left }
        })()
      JS
      assert_operator layout["badgesLeft"], :<, 1, "les badges ne sont pas au bord gauche du pied"
      assert_operator layout["circleRight"], :<, 1, "le cercle n'est pas au bord droit du pied"
      assert layout["badgesBeforeCircle"], "le cercle n'est pas isolé à droite des badges"

      click_on "Phases de la mitose"
    end

    assert_current_path classroom_assignment_path(@classroom.public_id, @assignment.public_id)
    within "#comprehension" do
      assert_selector "h2", text: "Compréhension"
      assert_text "Acquis"
      assert_text "10/13"
      # Signes : progrès = Adou, Bamba, Kouadio ; sans évolution = Sylla, Yao ; baisse = Zadi ; sans signe : les 4 autres.
      assert_selector "#comprehension_trends", text: "3 en progrès · 2 sans évolution · 1 en baisse"
      assert_category "En difficulté", 1
      assert_category "Fragile", 4
      assert_category "Acquis", 5
      assert_selector "nav a[aria-current=true]", count: 1, text: "Acquis"

      find("nav a", text: "Fragile").click

      assert_selector "nav a[aria-current=true]", count: 1, text: "Fragile"
    end
    assert_fragile_panel
    assert_current_path classroom_assignment_path(@classroom.public_id, @assignment.public_id, category: "fragile")

    page.driver.browser.navigate.refresh

    assert_current_path classroom_assignment_path(@classroom.public_id, @assignment.public_id, category: "fragile")
    assert_selector "#comprehension nav a[aria-current=true]", count: 1, text: "Fragile"
    assert_fragile_panel

    within "#pending_students" do
      assert_selector "h2", text: "Pas encore faits · 3"
      assert_equal [ "Zoé Abo", "Ibrahim Diallo", "Marc Touré" ], all("li").map(&:text)
    end
    assert_no_text(/\bessais?\b/i)
  end

  test "un élève de la classe qui force l'adresse du suivi est refusé (403)" do
    student = Orm::User.find_by!(first_name: "Paul", last_name: "Zadi")
    sign_in_as student
    url = classroom_assignment_path(@classroom.public_id, @assignment.public_id, category: "fragile")

    # Le navigateur ne montre pas le statut : il le lit par un fetch de même origine, avec le cookie de l'élève.
    assert_equal 403, page.evaluate_async_script("fetch(arguments[0]).then(r => arguments[1](r.status))", url)
    visit url
    assert_text I18n.t("errors.forbidden.title")
    assert_no_selector "#comprehension"
    assert_no_text "Fanta Sylla"
    assert_no_text "Zoé Abo"
  end

  test "sur un téléphone, le pied de l'exercice et la section tiennent dans la largeur" do
    sign_in_as @teacher
    with_mobile_viewport do
      visit classroom_path(@classroom.public_id)
      within "#assignment_#{@assignment.public_id}" do
        assert_text "Acquis · 10/13"
        assert_selector "ul[aria-label='Badges de la classe'] li", count: 4
      end
      assert_no_horizontal_scroll "la page de la classe"

      visit classroom_assignment_path(@classroom.public_id, @assignment.public_id, category: "fragile")
      assert_selector "#comprehension nav a[aria-current=true]", text: "Fragile"
      assert_selector "#comprehension_panel li", text: "Paul Zadi"
      assert_no_horizontal_scroll "le suivi"
    end
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

  def assert_category(label, count)
    assert_selector "nav[aria-label='Catégories'] a", text: /#{label}\s+#{count}\z/
  end

  def assert_fragile_panel
    within "#comprehension_panel" do
      assert_selector "li[aria-label='Question 1 : 100#{NBSP}% de réussite']"
      assert_selector "li[aria-label='Question 2 : 100#{NBSP}% de réussite, 50#{NBSP}% à la première session']",
                      text: "1re session : 50 %"
      # Q3 : juste à la 1re session de Sylla seule (25 %), fausse au meilleur essai de tous (0 %) : la classe a régressé.
      assert_selector "li[aria-label='Question 3 : 0#{NBSP}% de réussite, 25#{NBSP}% à la première session, à reprendre en classe']",
                      text: "À reprendre en classe"
      assert_selector "ol li", text: "À reprendre en classe", count: 1
      students = all("ul li").map { it.find("span", match: :first).text }
      assert_equal [ "Paul Zadi", "Fanta Sylla", "Aya Konan", "Bakary Adou" ], students
      assert_selector "ul li", text: /Paul Zadi\s+65 %\s+En baisse/
      assert_selector "ul li", text: /Aya Konan\s+67 %\s+1 session/
    end
  end

  def assert_no_horizontal_scroll(where)
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "#{where} déborde en largeur"
  end
end
