require "test_helper"

# Lot E of fonctions-espace-eleve (UDR-0062 §3.5, ADR-0072 §4.4, §4.5): the follow-up of an assigned exercise. Its
# teacher and the team read the three counts and the names of the students who handed it in late; a student, another
# teacher and the school's direction get 403, a visitor goes to the sign-in page. The policy runs before any reading.
# Lot B of rapports-exercices (ADR-0079, UDR-0072 §3.5, §3.5 bis, §3.6): the « Compréhension » section, its categories
# as links in a Turbo Frame (?category=), and the students not done yet, named.
class Classroom::AssignmentFollowUpsControllerTest < ActionDispatch::IntegrationTest
  DUE_ON = Date.new(2026, 10, 8)

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, name: "3ème B")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    svt = create_material(name: "SVT", category: "science")
    @exercise = create_exercise(essential: create_essential(course: create_course(material: svt)), title: "La méiose")
    @assignment = travel_to(Time.zone.local(2026, 10, 2, 9)) do
      create_assignment(classroom: @classroom, assignable: @exercise, by: @teacher, due_on: DUE_ON)
    end
    @late = [ %w[Koffi Yao], %w[Awa Bamba] ].map do |first_name, last_name|
      create_student(classroom: @classroom, first_name:, last_name:).tap { hand_in(it, Time.zone.local(2026, 10, 9, 10)) }
    end
    @on_time = create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
    hand_in(@on_time, Time.zone.local(2026, 10, 8, 18))
    @pending = create_student(classroom: @classroom, first_name: "Zoé", last_name: "Pas-Encore")
  end

  def scope = "classroom.assignment_follow_ups.show"
  def follow_up_path(assignment = @assignment) = classroom_assignment_path(@classroom.public_id, assignment.public_id)

  def hand_in(student, at, assignment: @assignment)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed",
                            classroom_assignment: assignment, completed_at: at)
  end

  test "the classroom's teacher reads the counts and the late students, by name, with the day of their first hand-in" do
    sign_in_as @teacher

    get follow_up_path

    assert_response :success
    assert_select "title", text: "La méiose · Enseignant · Lnclass"
    assert_select "nav[aria-label='Retour'] a[href='#{classroom_path(@classroom.public_id)}']", text: "3ème B"
    assert_select "p", text: I18n.t("#{scope}.context", classroom: "3ème B", school: "Lycée Classique d'Abidjan")
    assert_select "h1", text: "La méiose"
    assert_select "body", text: /SVT/
    assert_select "body", text: /Pour jeu\. 8 oct\./
    assert_select "body", text: /#{I18n.t("#{scope}.assigned_on", date: "2 oct.")}/
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: I18n.t("#{scope}.see_exercise")
    assert_select "dl#follow_up_counts" do
      assert_select "div", 3
      assert_select "dt", text: I18n.t("#{scope}.done")
      assert_select "dt", text: I18n.t("#{scope}.late")
      assert_select "dt", text: I18n.t("#{scope}.pending")
      assert_select "dd", text: "3"
      assert_select "dd", text: "2"
      assert_select "dd", text: "1"
    end
    assert_select "section#late_students h2", text: I18n.t("#{scope}.late_title")
    assert_select "section#late_students ul li", 2 do |items|
      assert_match(/Awa Bamba.*Fait le ven\. 9 oct\./m, items.first.text)
      assert_match(/Koffi Yao/, items.last.text)
    end
    assert_select "section#late_students", text: /Kouassi|Pas-Encore/, count: 0
  end

  test "no student identifier in the HTML of the follow-up" do
    sign_in_as @teacher

    get follow_up_path

    [ *@late, @on_time, @pending ].each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  test "the team reads it too, and comes back to the classroom" do
    sign_in_as create_team_member

    get follow_up_path

    assert_response :success
    assert_select "section#late_students li", 2
    assert_select "nav[aria-label='Retour'] a[href='#{classroom_path(@classroom.public_id)}']"
  end

  test "without a due date: no late count, no late section, and it says so" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    hand_in(@on_time, 1.hour.ago, assignment:)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_response :success
    assert_select "body", text: /#{I18n.t("due_dates.teacher.none")}/
    assert_select "dl#follow_up_counts div", 2
    assert_select "dt", text: I18n.t("#{scope}.late"), count: 0
    assert_select "#late_students", 0
    assert_select "p", text: I18n.t("#{scope}.no_due_date")
  end

  test "a due date nobody missed: no late section" do
    Orm::ExerciseSession.where(student: @late).update_all(completed_at: Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_response :success
    assert_select "dl#follow_up_counts dt", text: I18n.t("#{scope}.late")
    assert_select "#late_students", 0
    assert_select "p", text: I18n.t("#{scope}.no_due_date"), count: 0
  end

  test "an archived assignment, or one of another classroom, answers 404" do
    archived = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), status: "archived")
    elsewhere = create_classroom(school: @school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: elsewhere)
    sign_in_as @teacher

    get follow_up_path(archived)
    assert_response :not_found

    get classroom_assignment_path(elsewhere.public_id, @assignment.public_id)
    assert_response :not_found

    get classroom_assignment_path("inconnue", @assignment.public_id)
    assert_response :not_found
  end

  test "a student of the classroom gets 403, without any name" do
    sign_in_as @late.first

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Bamba|Kouassi|Pas-Encore/, response.body)
  end

  test "a teacher of another classroom gets 403, without any name" do
    sign_in_as create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ])

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Yao|Bamba|Kouassi/, response.body)
  end

  test "the school's direction gets 403: neither the late students nor any student identifier (UDR-0052)" do
    sign_in_as create_school_admin(school: @school)

    get follow_up_path

    assert_response :forbidden
    assert_no_match(/Yao|Bamba|Kouassi/, response.body)
    [ *@late, @on_time, @pending ].each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  # A readable classroom on a new assignment of three questions: 3 « Acquis », 1 « Fragile », 2 « En difficulté ».
  def build_quiz
    @quiz_exercise = create_exercise(essential: @exercise.essential, questions: 3)
    @quiz = create_assignment(classroom: @classroom, assignable: @quiz_exercise, by: @teacher)
    @questions = @quiz_exercise.questions.order(:position).to_a
    {
      %w[Ali Progres] => [ [ 30, { 1 => true, 2 => false } ], [ 90, { 1 => false, 2 => true } ] ],
      %w[Léa Stable] => [ [ 72, { 1 => true } ], [ 72, { 1 => false } ] ],
      %w[Marc Baisse] => [ [ 90, { 1 => true } ], [ 40, { 1 => false } ] ],
      %w[Fanta Fragile] => [ [ 60, { 1 => true, 2 => false } ], [ 65, { 1 => true, 2 => true } ] ],
      %w[Inès Difficile] => [ [ 40, {} ] ],
      %w[Omar Difficile] => [ [ 30, {} ] ]
    }.each_with_index do |((first_name, last_name), sessions), rank|
      student = create_student(classroom: @classroom, first_name:, last_name:)
      sessions.each_with_index do |(score_percent, answers), index|
        session = create_exercise_session(student:, exercise: @quiz_exercise, status: "completed", score_percent:, classroom_assignment: @quiz,
                                          completed_at: Time.zone.local(2026, 10, 3 + index, 8 + rank))
        answers.each { |position, correct| create_attempt(session:, question: @questions[position - 1], correct:) }
      end
    end
  end

  def percent(rate) = "#{rate}\u00A0%"

  test "the « Compréhension » section: the big circle, the summary of the signs and the three categories, the dominant one chosen" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_response :success
    assert_select "section#comprehension[aria-labelledby=comprehension_title] h2#comprehension_title", text: "Compréhension"
    assert_select "turbo-frame#comprehension_frame[data-turbo-action=advance]" do
      assert_select "span.size-14.bg-success"
      assert_select "span", text: "Acquis"
      assert_select "span", text: "6/10"
      assert_select "p#comprehension_trends", text: "1 en progrès · 2 sans évolution · 1 en baisse"
      assert_select "p", text: I18n.t("assessment.comprehension.unreliable"), count: 0
      assert_select "nav[aria-label=Catégories] a", 3
      { struggling: [ "En difficulté", 2 ], fragile: [ "Fragile", 1 ], acquired: [ "Acquis", 3 ] }.each do |category, (label, count)|
        assert_select "nav a[href='#{classroom_assignment_path(@classroom.public_id, @quiz.public_id, category:)}']", text: /#{label}\s*#{count}/
      end
      assert_select "nav a[aria-current=true]", 1
      assert_select "nav a[aria-current=true][href$='category=acquired']"
      assert_select "#comprehension_panel section[aria-labelledby=comprehension_students_title] ul li", 3
    end
    assert_operator response.body.index("follow_up_counts"), :<, response.body.index("comprehension_title")
  end

  test "the questions of a category: rate on the best session, first session, to revisit, « — » without attempt, in order" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_select "#comprehension_panel h3#comprehension_questions_title", text: "Questions"
    assert_select "#comprehension_panel ol li", 3 do |items|
      first, second, third = items
      assert_equal "Question 1 : #{percent(33)} de réussite, #{percent(100)} à la première session, à reprendre en classe", first["aria-label"]
      assert_match(/Q1.*Question 1.*À reprendre en classe.*#{percent(33)}.*1re session : #{percent(100)}/m, first.text)
      assert_match(/Q2.*Question 2.*#{percent(100)}.*1re session : #{percent(0)}/m, second.text)
      assert_no_match(/À reprendre/, second.text)
      assert_equal "Question 3 : — de réussite", third["aria-label"]
      assert_match(/Q3.*Question 3.*—/m, third.text)
    end
    assert_select "#comprehension_panel ol li:nth-child(3) .h-2", 0
    assert_select "#comprehension_panel ol li:nth-child(1) .h-2 svg.bg-struggling[width='33%']"
    assert_select "#comprehension_panel ol li:nth-child(2) .h-2 svg.bg-success[width='100%']"
  end

  test "the students of a category, the ones who need the teacher first, with best score and sign" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_select "#comprehension_panel h3#comprehension_students_title", text: "Élèves"
    assert_select "#comprehension_panel ul li", 3 do |items|
      [ [ "Marc Baisse", 90, "En baisse" ], [ "Léa Stable", 72, "Stable" ], [ "Ali Progres", 90, "En progrès" ] ].zip(items)
                                                                                                         .each do |(name, best, sign), item|
        assert_match(/\A\s*#{name}\s*#{percent(best)}\s*#{sign}\s*\z/, item.text)
      end
    end
    assert_select "#comprehension_panel ul li a", 0
  end

  test "the category in the address: ?category=fragile chooses « Fragile »; an unknown one is ignored" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { category: "fragile" }

    assert_select "nav a[aria-current=true][href$='category=fragile']", text: /Fragile/
    assert_select "#comprehension_panel ul li", 1 do
      assert_select "span", text: "Fanta Fragile"
      assert_select "span", text: "Stagne"
    end
    assert_select "#comprehension_panel ol li:first-child", text: /#{percent(100)}/
    assert_select "#comprehension_panel ol li:nth-child(2)", text: /1re session : #{percent(0)}/

    [ "inconnue", "STRUGGLING", "fragile ", "" ].each do |category|
      get follow_up_path(@quiz), params: { category: }

      assert_response :success
      assert_select "nav a[aria-current=true][href$='category=acquired']"
    end
    get follow_up_path(@quiz), params: { category: [ "fragile" ] }
    assert_select "nav a[aria-current=true][href$='category=acquired']"
  end

  test "a category without any student: its empty state instead of the two lists" do
    build_quiz
    sign_in_as @teacher
    Orm::ExerciseSession.where(classroom_assignment: @quiz, score_percent: 60..69).update_all(score_percent: 75)

    get follow_up_path(@quiz), params: { category: "fragile" }

    assert_select "#comprehension_panel" do
      assert_select "p", text: I18n.t("assessment.comprehension.empty_category")
      assert_select "ol, ul", 0
    end
    assert_select "nav a[aria-current=true][href$='category=fragile']", text: /0/
  end

  test "under 5 done: a grey circle, the warning, and the detail still shown; no sign yet without a second session" do
    sign_in_as @teacher

    get follow_up_path

    assert_select "#comprehension_frame" do
      assert_select "span.size-14.bg-line"
      assert_select "span", text: "Pas encore lisible"
      assert_select "span", text: "3/4"
      assert_select "p", text: I18n.t("assessment.comprehension.unreliable")
      assert_select "p#comprehension_trends", text: I18n.t("assessment.comprehension.no_trend")
      assert_select "nav a[aria-current=true][href$='category=acquired']"
      assert_select "#comprehension_panel ul li", 3
      assert_select "#comprehension_panel ul li", text: /1 session/, count: 3
      assert_select "#comprehension_panel ol li", 2 do |items|
        items.each { assert_match(/—/, it.text) }
      end
    end
  end

  test "nobody did it: the empty state of the section, without categories nor panel" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_select "#comprehension_frame" do
      assert_select "p", text: I18n.t("assessment.comprehension.empty.title")
      assert_select "p", text: I18n.t("assessment.comprehension.empty.description")
      assert_select "nav, #comprehension_panel, #comprehension_trends", 0
    end
  end

  test "« Pas encore faits · 7 » names the students not done yet, the one with a started session too, never one gone" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    hand_in(@on_time, 1.hour.ago, assignment:)
    started = create_student(classroom: @classroom, first_name: "Sali", last_name: "Commencé")
    create_exercise_session(student: started, exercise: Orm::Exercise.find(assignment.assignable_id), classroom_assignment: assignment)
    create_student(classroom: @classroom, first_name: "Paul", last_name: "Attente")
    create_student(classroom: @classroom, first_name: "Rita", last_name: "Attente")
    create_student(classroom: @classroom, first_name: "Moussa", last_name: "Diallo")
    create_student(classroom: @classroom, first_name: "Gone", last_name: "Parti").then { Orm::ClassroomStudent.where(student: it).update_all(left_at: Time.current) }
    create_student(classroom: @classroom, first_name: "Anon", last_name: "Yme").update_columns(anonymized_at: Time.current)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_select "section#pending_students[aria-labelledby=pending_students_title]" do
      assert_select "h2#pending_students_title", text: "Pas encore faits · 7"
      assert_select "ul li", 7 do |items|
        assert_equal [ "Paul Attente", "Rita Attente", "Awa Bamba", "Sali Commencé", "Moussa Diallo", "Zoé Pas-Encore", "Koffi Yao" ],
                     items.map { it.text.strip }
      end
      assert_select "ul li a", 0
    end
    assert_select "#pending_students", text: /Parti|Yme|Kouassi/, count: 0
    assert_operator response.body.index("pending_students_title"), :>, response.body.index("comprehension_title")
    [ @pending, started ].each { assert_no_match(/#{it.public_id}/, response.body) }
  end

  test "one student not done yet: « Pas encore fait · 1 », after the late ones" do
    sign_in_as @teacher

    get follow_up_path

    assert_select "h2#pending_students_title", text: "Pas encore fait · 1"
    assert_select "#pending_students li", text: "Zoé Pas-Encore"
    assert_operator response.body.index("pending_students_title"), :>, response.body.index("late_students_title")
  end

  test "everybody did it: no « Pas encore faits » section, the counts and the late ones unchanged" do
    hand_in(@pending, Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_select "#pending_students", 0
    assert_select "dl#follow_up_counts dd", text: "4"
    assert_select "dl#follow_up_counts dd", text: "0"
    assert_select "section#late_students li", 2
  end

  test "the rate at the first session is hidden where it equals the rate on the best session (UDR-0072 §3.5)" do
    exercise = create_exercise(essential: @exercise.essential, questions: 2)
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher)
    questions = exercise.questions.order(:position).to_a
    student = create_student(classroom: @classroom, first_name: "Ali", last_name: "Progres")
    [ [ 40, { 1 => true, 2 => false } ], [ 90, { 1 => true, 2 => true } ] ].each_with_index do |(score_percent, answers), index|
      session = create_exercise_session(student:, exercise:, status: "completed", score_percent:, classroom_assignment: assignment,
                                        completed_at: Time.zone.local(2026, 10, 3 + index, 8))
      answers.each { |position, correct| create_attempt(session:, question: questions[position - 1], correct:) }
    end
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_select "#comprehension_panel ol li", 2 do |(same, moved)|
      assert_equal "Question 1 : #{percent(100)} de réussite", same["aria-label"]
      assert_no_match(/1re session/, same.text)
      assert_equal "Question 2 : #{percent(100)} de réussite, #{percent(0)} à la première session", moved["aria-label"]
      assert_match(/1re session : #{percent(0)}/, moved.text)
    end
  end

  test "a classroom without any present student: the empty state of the section, no « Pas encore faits » section" do
    classroom = create_classroom(school: @school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    assignment = create_assignment(classroom:, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    gone = create_student(classroom:, first_name: "Gone", last_name: "Parti")
    hand_in(gone, 1.hour.ago, assignment:)
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    sign_in_as @teacher

    get classroom_assignment_path(classroom.public_id, assignment.public_id)

    assert_response :success
    assert_select "section#comprehension h2#comprehension_title", text: "Compréhension"
    assert_select "#comprehension_frame" do
      assert_select "p", text: "Personne n'a encore fait cet exercice."
      assert_select "nav, #comprehension_panel, #comprehension_trends", 0
    end
    assert_select "#pending_students", 0
    assert_no_match(/Parti/, response.body)
  end

  test "an archived classroom stays readable: the « Compréhension » section, and a category can be chosen" do
    classroom = create_classroom(school: @school, status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    assignment = create_assignment(classroom:, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    [ 100, 90, 80, 60, 40 ].each_with_index do |score_percent, index|
      student = create_student(classroom:, first_name: "Élève", last_name: "N#{index}")
      create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed", score_percent:,
                              classroom_assignment: assignment)
    end
    sign_in_as @teacher

    get classroom_assignment_path(classroom.public_id, assignment.public_id)

    assert_response :success
    assert_select "section#comprehension h2#comprehension_title", text: "Compréhension"
    assert_select "#comprehension_frame span", text: "Acquis"
    assert_select "nav a[aria-current=true][href$='category=acquired']"

    get classroom_assignment_path(classroom.public_id, assignment.public_id), params: { category: "fragile" }

    assert_response :success
    assert_select "nav a[aria-current=true][href$='category=fragile']", text: /Fragile\s*1/
    assert_select "#comprehension_panel ul li", 1 do
      assert_select "span", text: "Élève N3"
    end
  end

  test "a student, a teacher of another classroom and the direction asking for a category get 403, and a body without any reading" do
    build_quiz
    names = /Progres|Stable|Baisse|Fragile|Difficile|Yao|Bamba|Kouassi|Pas-Encore/
    asker = Orm::User.find_by!(first_name: "Fanta", last_name: "Fragile")
    {
      asker => /Progres|Stable|Baisse|Difficile|Yao|Bamba|Kouassi|Pas-Encore/,
      create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ]) => names,
      create_school_admin(school: @school) => names
    }.each do |actor, forbidden_names|
      sign_in_as actor

      get follow_up_path(@quiz), params: { category: "fragile" }

      assert_response :forbidden
      assert_select "#comprehension, #comprehension_frame, #pending_students", 0
      assert_select "h2", text: "Compréhension", count: 0
      assert_no_match(forbidden_names, response.body)
      assert_no_match(/Badges de la classe|1re session|À reprendre en classe/, response.body)
      sign_out
    end
  end

  test "a visitor is sent to the sign-in page" do
    get follow_up_path

    assert_redirected_to new_session_path
  end
end
