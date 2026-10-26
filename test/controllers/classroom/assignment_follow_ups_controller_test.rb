require "test_helper"

# Lot E of fonctions-espace-eleve (UDR-0062 §3.5, ADR-0072 §4.4, §4.5): the follow-up of an assigned exercise. Its
# teacher and the team read the three counts and the names of the students who handed it in late; a student, another
# teacher and the school's direction get 403, a visitor goes to the sign-in page. The policy runs before any reading.
# Lot B of rapports-exercices (ADR-0079, UDR-0072 §3.5, §3.5 bis, §3.6): the « Compréhension » section, its categories
# as links in a Turbo Frame (?category=), and the students not done yet, named.
# Lot K of mvp-teacher-student (UDR enseignant §3.8, CA-I4, CA-I5): « 20 / 27 faits », the late pill hidden at zero, five boxes by badge
# that filter the list of the students (?badge=, Turbo Frame), the next step said in badges. The big circle is gone.
# Lot C of rapports-de-classe (ADR-0097 §4.6, §4.9, UDR-0109): every name leads to the student's file in this classroom
# (out of the frame of the categories), and a « next step » sentence heads the « Compréhension » section.
class Classroom::AssignmentFollowUpsControllerTest < ActionDispatch::IntegrationTest
  DUE_ON = Date.new(2026, 10, 8)

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, name: "3ème B")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    svt = create_material(name: "SVT", category: "science", shortname: "SVT")
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
    assert_select "p", text: /SVT · 2 questions · à rendre jeu\. 8 oct\./
    assert_select "body", text: /#{I18n.t("#{scope}.assigned_on", date: "2 oct.")}/
    assert_select "a[href='#{exercise_path(@exercise.public_id)}']", text: I18n.t("#{scope}.see_exercise")
    assert_select "dl#follow_up_counts", 0
    assert_select "#follow_up_progress" do
      assert_select "[role=progressbar][aria-valuenow='3'][aria-valuemax='4']"
      assert_select "span", text: "3 / 4 faits"
      assert_select "span", text: "2 en retard"
    end
    assert_select "#follow_up_progress .bg-teacher"
    assert_select "section#late_students h2", text: I18n.t("#{scope}.late_title")
    assert_select "section#late_students ul li", 2 do |items|
      assert_match(/Awa Bamba.*Fait le ven\. 9 oct\./m, items.first.text)
      assert_match(/Koffi Yao/, items.last.text)
    end
    assert_select "section#late_students", text: /Kouassi|Pas-Encore/, count: 0
  end

  def file_path(student, classroom: @classroom) = classroom_student_path(classroom.public_id, student.public_id)

  test "Q8: every name leads to the student's file: the categories (out of their frame), the late ones, the ones not done yet" do
    sign_in_as @teacher

    get follow_up_path

    [ *@late, @on_time ].each do |student|
      assert_select "#comprehension_frame #comprehension_panel ul li a[href='#{file_path(student)}'][data-turbo-frame=_top]",
                    text: "#{student.first_name} #{student.last_name}"
    end
    @late.each { assert_select "section#late_students li a[href='#{file_path(it)}'][data-turbo-frame=_top]" }
    assert_select "section#pending_students li a[href='#{file_path(@pending)}'][data-turbo-frame=_top]", text: "Zoé Pas-Encore"
  end

  test "the team reads it too, and comes back to the classroom" do
    sign_in_as create_team_member

    get follow_up_path

    assert_response :success
    assert_select "section#late_students li", 2
    assert_select "nav[aria-label='Retour'] a[href='#{classroom_path(@classroom.public_id)}']"
  end

  test "the meta line says « Maths », never « Math », and the question count; one question reads in the singular" do
    maths = create_material(name: "Mathématiques", category: "science", shortname: "Maths")
    exercise = create_exercise(essential: create_essential(course: create_course(material: maths)), questions: 1)
    assignment = create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, due_on: Date.new(2026, 10, 30))
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_select "p", text: /\AMaths · 1 question · à rendre ven\. 30 oct\./
    assert_select "p", text: /Math ·/, count: 0
  end

  test "without a due date: no late count, no late section, and it says so" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    hand_in(@on_time, 1.hour.ago, assignment:)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_response :success
    assert_select "p", text: /sans date limite/
    assert_select "#follow_up_progress span", text: /en retard/, count: 0
    assert_select "#late_students", 0
    assert_select "p", text: I18n.t("#{scope}.no_due_date")
  end

  test "a due date nobody missed: no late section" do
    Orm::ExerciseSession.where(student: @late).update_all(completed_at: Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_response :success
    assert_select "#follow_up_progress span", text: "3 / 4 faits"
    assert_select "#follow_up_progress span", text: /en retard/, count: 0
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

  # A readable classroom on a new assignment of three questions: best scores 90, 72, 90, 65, 40, 30: 2 Or, 1 Argent, 1 Bronze, 2 Pas encore.
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

  test "the « Compréhension » section: the progress, the five boxes by badge, the summary of the signs, the next step, no big circle" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_response :success
    assert_select "section#comprehension[aria-labelledby=comprehension_title] h2#comprehension_title", text: "Compréhension"
    assert_select "turbo-frame#comprehension_frame[data-turbo-action=advance]" do
      assert_select "span.size-14", 0
      assert_select "#follow_up_progress span", text: "6 / 10 faits"
      assert_select "#follow_up_progress span", text: /en retard/, count: 0
      assert_select "p#comprehension_trends", text: "1 en progrès · 2 sans évolution · 1 en baisse"
      assert_select "#comprehension_next_step", text: /Prochain geste\s+La classe a atteint l'Argent ou mieux\. Un élève est en baisse/
      assert_select "nav[aria-label='Élèves par badge'] a", 5
      { none: [ "Pas encore", 2 ], bronze: [ "Bronze", 1 ], silver: [ "Argent", 1 ], gold: [ "Or", 2 ], diamond: [ "Diamant", 0 ] }.each do |badge, (label, count)|
        assert_select "nav a[href='#{classroom_assignment_path(@classroom.public_id, @quiz.public_id, badge:)}']", text: /#{count}\s*#{label}/
      end
      assert_select "nav a[aria-current=true]", 0
      assert_select "#comprehension_panel section[aria-labelledby=comprehension_students_title] ul li", 6
    end
    assert_operator response.body.index("follow_up_progress"), :<, response.body.index("comprehension_next_step")
  end

  test "the next step speaks in badges, never « En difficulté », « Fragile » or « Acquis » (CA-I5)" do
    build_quiz
    sign_in_as @teacher
    Orm::ExerciseSession.where(classroom_assignment: @quiz).update_all(score_percent: 30)

    get follow_up_path(@quiz)

    assert_select "#comprehension_next_step", text: /6 élèves n'ont pas encore de badge\. Reprenez la notion en classe avant d'avancer, puis relancez-les\./
    assert_select "#comprehension_next_step", text: /difficulté|Fragile|Acquis/, count: 0
    assert_select "#comprehension nav, #comprehension_questions", text: /En difficulté|Fragile|Acquis/, count: 0
  end

  test "the questions, read on the students listed: rate on the best session, first session, to revisit, « — » without attempt, in order" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "gold" }

    assert_select "#comprehension_questions h3#comprehension_questions_title", text: "Questions"
    assert_select "#comprehension_questions ol li", 3 do |items|
      first, second, third = items
      assert_equal "Question 1 : #{percent(50)} de réussite, #{percent(100)} à la première session", first["aria-label"]
      assert_match(/Q1.*Question 1.*#{percent(50)}.*1re session : #{percent(100)}/m, first.text)
      assert_match(/Q2.*Question 2.*#{percent(100)}.*1re session : #{percent(0)}/m, second.text)
      assert_no_match(/À reprendre/, second.text)
      assert_equal "Question 3 : — de réussite", third["aria-label"]
      assert_match(/Q3.*Question 3.*—/m, third.text)
    end
    assert_select "#comprehension_questions ol li:nth-child(3) .h-2", 0
    assert_select "#comprehension_questions ol li:nth-child(2) .h-2 svg.bg-success[width='100%']"
  end

  test "the students of the list, the ones who need the teacher first, with best score and sign" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "gold" }

    assert_select "#comprehension_panel h3#comprehension_students_title", text: "Élèves"
    assert_select "#comprehension_panel ul li", 2 do |items|
      [ [ "Marc Baisse", 90, "En baisse" ], [ "Ali Progres", 90, "En progrès" ] ].zip(items).each do |(name, best, sign), item|
        assert_match(/\A\s*#{name}\s*#{percent(best)}\s*#{sign}\s*\z/, item.text)
      end
    end
    assert_select "#comprehension_panel ul li a[data-turbo-frame=_top]", 2
  end

  test "?badge=bronze filters the list on « Bronze » and marks its box; the box touched again links back to everybody" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "bronze" }

    assert_select "nav a[aria-current=true][href='#{follow_up_path(@quiz)}']", text: /1\s*Bronze/
    assert_select "#comprehension_panel ul li", 1 do
      assert_select "a[data-turbo-frame=_top]", text: "Fanta Fragile"
      assert_select "span", text: "Stagne"
    end
    assert_select "#comprehension_questions ol li:first-child", text: /#{percent(100)}/
    assert_select "#comprehension_questions ol li:nth-child(2)", text: /1re session : #{percent(0)}/
    assert_select "#follow_up_progress span", text: "6 / 10 faits"
    assert_select "nav a", text: /2\s*Pas encore/
  end

  test "an unknown badge, the old ?category= or an array is ignored: the whole list, no box active" do
    build_quiz
    sign_in_as @teacher

    [ { badge: "inconnue" }, { badge: "GOLD" }, { badge: "gold " }, { badge: "" }, { badge: [ "gold" ] }, { category: "fragile" } ].each do |params|
      get follow_up_path(@quiz), params: params

      assert_response :success
      assert_select "nav a[aria-current=true]", 0
      assert_select "#comprehension_panel ul li", 6
    end
  end

  test "a badge without any student: its empty state instead of the two lists, the counts unchanged" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "diamond" }

    assert_select "#comprehension_panel" do
      assert_select "p", text: I18n.t("assessment.comprehension.empty_category")
      assert_select "ol, ul", 0
    end
    assert_select "#comprehension_questions", 0
    assert_select "nav a[aria-current=true]", text: /0\s*Diamant/
    assert_select "nav a", text: /2\s*Pas encore/
  end

  test "under 5 done: no circle, the next step says the bound, and the detail still shown; no sign yet without a second session" do
    sign_in_as @teacher

    get follow_up_path

    assert_select "#comprehension_frame" do
      assert_select "span.size-14", 0
      assert_select "span", text: "3 / 4 faits"
      assert_select "#comprehension_next_step", text: /Relancez l'élève qui ne l'a pas encore fait : les badges de la classe se liront à partir de 5 élèves\./
      assert_select "p#comprehension_trends", text: I18n.t("assessment.comprehension.no_trend")
      assert_select "nav a", 5
      assert_select "#comprehension_panel ul li", 3
      assert_select "#comprehension_panel ul li", text: /1 session/, count: 3
      assert_select "#comprehension_questions ol li", 2 do |items|
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
      assert_select "#follow_up_progress span", text: "0 / 4 fait"
      assert_select "nav, #comprehension_panel, #comprehension_trends, #comprehension_next_step", 0
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
      assert_select "ul li a", 7
      [ @pending, started ].each { assert_select "ul li a[href='#{file_path(it)}']" }
    end
    assert_select "#pending_students", text: /Parti|Yme|Kouassi/, count: 0
    assert_operator response.body.index("pending_students_title"), :>, response.body.index("comprehension_title")
  end

  test "one student not done yet: « Pas encore fait · 1 », after the late ones" do
    sign_in_as @teacher

    get follow_up_path

    assert_select "h2#pending_students_title", text: "Pas encore fait · 1"
    assert_select "#pending_students li", text: "Zoé Pas-Encore"
    assert_operator response.body.index("pending_students_title"), :>, response.body.index("late_students_title")
  end

  # ADR-0079 §4.1: a lacune opened by another exercise of the fiche makes the assigned exercise a remediation; it is done.
  test "a student whose only session on the assignment is a remediation is done, not « pas encore fait »" do
    remediated = create_student(classroom: @classroom, first_name: "Ali", last_name: "Remédié")
    create_exercise_session(student: remediated, exercise: @exercise, status: "completed", classroom_assignment: @assignment,
                            completed_at: Time.zone.local(2026, 10, 7, 10), gap: create_gap(student: remediated, essential: @exercise.essential))
    sign_in_as @teacher

    get follow_up_path

    assert_select "#follow_up_progress span", text: "4 / 5 faits"
    assert_select "#pending_students li", 1
    assert_select "#pending_students li", text: "Zoé Pas-Encore"
    assert_select "#pending_students", text: /Remédié/, count: 0
  end

  test "everybody did it: no « Pas encore faits » section, the counts and the late ones unchanged" do
    hand_in(@pending, Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_select "#pending_students", 0
    assert_select "#follow_up_progress span", text: "4 / 4 faits"
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

    assert_select "#comprehension_questions ol li", 2 do |(same, moved)|
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

  # vie-de-la-classe, Lot C (Q8) : le suivi nominatif d'une classe archivée n'est plus lisible (était : lisible, catégories comprises).
  test "an archived classroom: 404 for its teacher, a badge changes nothing" do
    classroom = create_classroom(school: @school, status: "archived")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    assignment = create_assignment(classroom:, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    student = create_student(classroom:, first_name: "Élève", last_name: "N3")
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed", score_percent: 60,
                            classroom_assignment: assignment)
    sign_in_as @teacher

    [ {}, { badge: "bronze" } ].each do |params|
      get classroom_assignment_path(classroom.public_id, assignment.public_id), params: params

      assert_response :not_found
      assert_no_match "Élève N3", response.body
    end
  end

  test "a student, a teacher of another classroom and the direction asking for a badge get 403, and a body without any reading" do
    build_quiz
    names = /Progres|Stable|Baisse|Fragile|Difficile|Yao|Bamba|Kouassi|Pas-Encore/
    asker = Orm::User.find_by!(first_name: "Fanta", last_name: "Fragile")
    {
      asker => /Progres|Stable|Baisse|Difficile|Yao|Bamba|Kouassi|Pas-Encore/,
      create_teacher(school: @school, classrooms: [ create_classroom(school: @school) ]) => names,
      create_school_admin(school: @school) => names
    }.each do |actor, forbidden_names|
      sign_in_as actor

      get follow_up_path(@quiz), params: { badge: "bronze" }

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
