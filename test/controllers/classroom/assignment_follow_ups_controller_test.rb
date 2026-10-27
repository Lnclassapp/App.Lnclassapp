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
# Correction of the report (maquette, decision of 2026-10-26): no title above the bar, no summary of the signs, a question reads
# « 1. statement · 18 / 20 justes » with its bar, a student « initials · name · Fait le 22 oct. · trophy 16/20 », and the ones who
# did not do it close the same list, « En retard » once the due date has passed. No section of late or pending students.
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
    @late = [ [ %w[Koffi Yao], 60 ], [ %w[Awa Bamba], 90 ] ].map do |(first_name, last_name), score_percent|
      create_student(classroom: @classroom, first_name:, last_name:).tap { hand_in(it, Time.zone.local(2026, 10, 9, 10), score_percent:) }
    end
    @on_time = create_student(classroom: @classroom, first_name: "Jean", last_name: "Kouassi")
    hand_in(@on_time, Time.zone.local(2026, 10, 8, 18))
    @pending = create_student(classroom: @classroom, first_name: "Zoé", last_name: "Pas-Encore")
  end

  def scope = "classroom.assignment_follow_ups.show"
  def follow_up_path(assignment = @assignment) = classroom_assignment_path(@classroom.public_id, assignment.public_id)

  def hand_in(student, at, assignment: @assignment, score_percent: 100)
    create_exercise_session(student:, exercise: Orm::Exercise.find(assignment.assignable_id), status: "completed", score_percent:,
                            classroom_assignment: assignment, completed_at: at)
  end

  test "the classroom's teacher reads the header, the progress and one list: who did it, best first, then who did not (late after the due date)" do
    sign_in_as @teacher

    travel_to(Time.zone.local(2026, 10, 12, 9)) { get follow_up_path }

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
      # « N en retard » : les élèves qui n'ont pas fait l'exercice la date limite passée (ceux qui portent « En retard »), pas les
      # rendus tardifs (Koffi et Awa, qui ne portent aucune pastille).
      assert_select "span", text: "1 en retard"
    end
    assert_select "#follow_up_progress .bg-teacher"
    assert_select "#late_students, #pending_students", 0
    assert_select "h2", text: "Compréhension", count: 0
    assert_select "#comprehension_panel h3#comprehension_students_title", text: "Élèves"
    assert_select "#comprehension_panel li", 4 do |(best, good, passed, pending)|
      assert_match(%r{\A\s*JK\s*Jean Kouassi\s*Fait le 8 oct\.\s*.*20/20\s*\z}m, best.text)
      assert_select best, "svg.text-info"
      assert_match(%r{Awa Bamba\s*Fait le 9 oct\.\s*.*18/20}m, good.text)
      assert_select good, "svg.text-gold"
      assert_match(%r{Koffi Yao\s*Fait le 9 oct\.\s*.*12/20}m, passed.text)
      assert_select passed, "svg.text-warning"
      assert_match(/\A\s*ZP\s*Zoé Pas-Encore\s*Pas encore fait\s*En retard\s*\z/, pending.text)
      assert_select pending, "svg", 0
    end
  end

  def file_path(student, classroom: @classroom) = classroom_student_path(classroom.public_id, student.public_id)

  test "Q8: every name of the list leads to the student's file (out of the frame of the boxes), the ones not done yet too" do
    sign_in_as @teacher

    get follow_up_path

    [ *@late, @on_time, @pending ].each do |student|
      assert_select "#comprehension_frame #comprehension_panel ul li a[href='#{file_path(student)}'][data-turbo-frame=_top]",
                    text: "#{student.first_name} #{student.last_name}"
    end
  end

  test "the team reads it too, and comes back to the classroom" do
    sign_in_as create_team_member

    get follow_up_path

    assert_response :success
    assert_select "#comprehension_panel li", 4
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

  test "without a due date: no late count, no « En retard » for who did not do it, « sans date limite » in the meta line only" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    hand_in(@on_time, 1.hour.ago, assignment:)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_response :success
    assert_select "p", text: /sans date limite/
    assert_select "#follow_up_progress span", text: /en retard/, count: 0
    assert_select "#comprehension_panel li", 4
    assert_select "#comprehension_panel li", text: /Pas encore fait/, count: 3
    assert_select "body", text: /En retard/, count: 0
    assert_select "#late_students", 0
    assert_select "p", text: /pas de date limite/, count: 0
  end

  test "a due date nobody missed: no late count, nobody late in the list" do
    Orm::ExerciseSession.where(student: @late).update_all(completed_at: Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    travel_to(Time.zone.local(2026, 10, 7, 12)) { get follow_up_path }

    assert_response :success
    assert_select "#follow_up_progress span", text: "3 / 4 faits"
    assert_select "#follow_up_progress span", text: /en retard/, count: 0
    assert_select "body", text: /En retard/, count: 0
    assert_select "#comprehension_panel li", text: /Zoé Pas-Encore\s*Pas encore fait\s*\z/
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

  test "the « Compréhension » section: no title, the progress, the five boxes by badge, the next step, no summary of the signs, no big circle" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_response :success
    assert_select "section#comprehension[aria-label=Compréhension]"
    assert_select "#comprehension h2, #comprehension_trends", 0
    assert_select "body", text: /en progrès|sans évolution|en baisse|\bQ\d\b|1re session|À reprendre en classe/, count: 0
    assert_select "turbo-frame#comprehension_frame[data-turbo-action=advance]" do
      assert_select "span.size-14", 0
      assert_select "#follow_up_progress span", text: "6 / 10 faits"
      assert_select "#follow_up_progress span", text: /en retard/, count: 0
      assert_select "#comprehension_next_step", text: /Prochain geste\s+La classe a atteint l'Argent ou mieux\. Un élève est en baisse/
      assert_select "nav[aria-label='Élèves par badge'] a", 5
      { none: [ "Pas encore", 2 ], bronze: [ "Bronze", 1 ], silver: [ "Argent", 1 ], gold: [ "Or", 2 ], diamond: [ "Diamant", 0 ] }.each do |badge, (label, count)|
        assert_select "nav a[href='#{classroom_assignment_path(@classroom.public_id, @quiz.public_id, badge:)}']", text: /#{count}\s*#{label}/
      end
      assert_select "nav a[aria-current=true]", 0
      assert_select "#comprehension_panel section[aria-labelledby=comprehension_students_title] ul li", 10
    end
    assert_operator response.body.index("follow_up_progress"), :<, response.body.index("comprehension_next_step")
  end

  test "the next step speaks in badges, never « En difficulté », « Fragile » or « Acquis » (CA-I5)" do
    build_quiz
    sign_in_as @teacher
    Orm::ExerciseSession.where(classroom_assignment: @quiz).update_all(score_percent: 30)

    get follow_up_path(@quiz)

    assert_select "#comprehension_next_step", text: /6 élèves n'ont pas encore de badge\. Reprenez la question 1 en classe, puis relancez-les\./
    assert_select "#comprehension_next_step", text: /difficulté|Fragile|Acquis/, count: 0
    assert_select "#comprehension nav, #comprehension_questions", text: /En difficulté|Fragile|Acquis/, count: 0
  end

  test "the late pill counts the students who did not do it once the due date has passed, whatever the badge asked; hidden before the date" do
    Orm::ExerciseSession.where(student: @late).update_all(completed_at: Time.zone.local(2026, 10, 7, 10))
    create_student(classroom: @classroom, first_name: "Paul", last_name: "Attente")
    sign_in_as @teacher

    travel_to(Time.zone.local(2026, 10, 9, 8)) do
      get follow_up_path
      assert_select "#follow_up_progress span", text: "2 en retard"
      assert_select "#comprehension_panel li", text: /En retard/, count: 2

      get follow_up_path, params: { badge: "diamond" }
      assert_select "#follow_up_progress span", text: "2 en retard"
      assert_select "#comprehension_panel li", text: /En retard/, count: 0
    end
    travel_to(Time.zone.local(2026, 10, 8, 20)) do
      get follow_up_path
      assert_select "#follow_up_progress span", text: /en retard/, count: 0
      assert_select "body", text: /En retard/, count: 0
    end
  end

  test "the questions read « 1. statement » and « 18 / 20 justes » on the students listed (best session), a bar beneath, « — » without attempt" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "gold" }

    assert_select "#comprehension_questions h3#comprehension_questions_title", text: "Questions"
    assert_select "#comprehension_questions ol li", 3 do |items|
      first, second, third = items
      assert_match(/\A1\.\s*Question 1\s*1 \/ 2 juste\s*\z/, first.text.squish)
      assert_match(/\A2\.\s*Question 2\s*1 \/ 1 juste\s*\z/, second.text.squish)
      assert_match(/\A3\.\s*Question 3\s*—\s*\z/, third.text.squish)
    end
    assert_select "#comprehension_questions ol li:nth-child(1) .h-2 svg.bg-teacher[width='50%']"
    assert_select "#comprehension_questions ol li:nth-child(2) .h-2 svg.bg-teacher[width='100%']"
    assert_select "#comprehension_questions ol li:nth-child(3) .h-2 svg", 0
    assert_select "#comprehension_questions", text: /%|Q1|1re session|À reprendre/, count: 0
  end

  test "the questions of the whole list count the students of every badge, « 18 / 20 justes » in the plural" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_select "#comprehension_questions ol li:nth-child(1)", text: /1\.\s*Question 1\s*2 \/ 4 justes/
    assert_select "#comprehension_questions ol li:nth-child(2)", text: /2\.\s*Question 2\s*2 \/ 2 justes/
  end

  test "a statement in LaTeX keeps its delimiters, and the list is rendered by KaTeX (ADR-0051)" do
    build_quiz
    @questions.first.update!(content: '<p>Calculer $\lim_{x \to 0} \frac{\sin x}{x}$.</p>')
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_select "#comprehension_questions ol[data-controller~=math]"
    assert_select "#comprehension_questions ol li:first-child p", text: 'Calculer $\lim_{x \to 0} \frac{\sin x}{x}$.'
  end

  test "the students of the list: initials, name, « Fait le … », the trophy of the badge and the grade on 20; best first, then by name" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "gold" }

    assert_select "#comprehension_panel h3#comprehension_students_title", text: "Élèves"
    assert_select "#comprehension_panel ul li", 2 do |items|
      [ [ "MB", "Marc Baisse" ], [ "AP", "Ali Progres" ] ].zip(items).each do |(initials, name), item|
        assert_match(%r{\A\s*#{initials}\s*#{name}\s*Fait le 3 oct\.\s*.*18/20\s*\z}m, item.text)
        assert_select item, "svg.text-gold"
      end
    end
    assert_select "#comprehension_panel ul li a[data-turbo-frame=_top].font-normal", 2
    assert_select "#comprehension_panel ul li a.font-medium", 0
    assert_select "#comprehension_panel", text: /%|session|baisse|progrès|Pas encore fait/, count: 0
  end

  test "the whole list: best score first, a student without badge has his grade and no trophy, then the ones not done yet, by name" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz)

    assert_select "#comprehension_panel ul li", 10 do |items|
      assert_equal [ "Marc Baisse", "Ali Progres", "Léa Stable", "Fanta Fragile", "Inès Difficile", "Omar Difficile",
                     "Awa Bamba", "Jean Kouassi", "Zoé Pas-Encore", "Koffi Yao" ], items.map { it.at_css("a").text }
      assert_match(%r{Inès Difficile\s*Fait le 3 oct\.\s*8/20\s*\z}, items[4].text)
      assert_select items[4], "svg", 0
      assert_select items[3], "svg.text-warning"
      items.to_a.last(4).each { assert_match(/Pas encore fait\s*\z/, it.text) } # the quiz has no due date: nobody late
    end
  end

  test "?badge=bronze filters the list on « Bronze » and marks its box; the box touched again links back to everybody" do
    build_quiz
    sign_in_as @teacher

    get follow_up_path(@quiz), params: { badge: "bronze" }

    assert_select "nav a[aria-current=true][href='#{follow_up_path(@quiz)}']", text: /1\s*Bronze/
    assert_select "#comprehension_panel ul li", 1 do
      assert_select "a[data-turbo-frame=_top]", text: "Fanta Fragile"
      assert_select "span", text: "13/20"
    end
    assert_select "#comprehension_panel", text: /Pas encore fait|En retard/, count: 0
    assert_select "#comprehension_questions ol li:first-child", text: /1\.\s*Question 1\s*1 \/ 1 juste/
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
      assert_select "#comprehension_panel ul li", 10
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
    assert_select "body", text: /Pas encore fait/, count: 0
    assert_select "#comprehension_questions", 0
    assert_select "nav a[aria-current=true]", text: /0\s*Diamant/
    assert_select "nav a", text: /2\s*Pas encore/
  end

  test "under 5 done: no circle, the next step says the bound, and the detail still shown, the one not done yet closing the list" do
    sign_in_as @teacher

    get follow_up_path

    assert_select "#comprehension_frame" do
      assert_select "span.size-14", 0
      assert_select "span", text: "3 / 4 faits"
      assert_select "#comprehension_next_step", text: /Relancez l'élève qui ne l'a pas encore fait : les badges de la classe se liront à partir de 5 élèves\./
      assert_select "#comprehension_trends", 0
      assert_select "nav a", 5
      assert_select "#comprehension_panel ul li", 4
      assert_select "#comprehension_panel ul li:last-child", text: /Zoé Pas-Encore/
      assert_select "#comprehension_questions ol li", 2 do |items|
        items.each { assert_match(/—/, it.text) }
      end
    end
  end

  test "nobody did it: the empty state of the section, no box nor question, every student listed as not done yet" do
    assignment = create_assignment(classroom: @classroom, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    sign_in_as @teacher

    get follow_up_path(assignment)

    assert_select "#comprehension_frame" do
      assert_select "p", text: I18n.t("assessment.comprehension.empty.title")
      assert_select "p", text: I18n.t("assessment.comprehension.empty.description")
      assert_select "#follow_up_progress span", text: "0 / 4 fait"
      assert_select "nav, #comprehension_questions, #comprehension_next_step", 0
      assert_select "#comprehension_panel ul li", 4 do |items|
        items.each { assert_match(/Pas encore fait/, it.text) }
      end
    end
  end

  test "the students not done yet close the list, by last name then first name: a started session too, never one who left or was anonymized" do
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

    assert_select "#comprehension_panel ul li", 8 do |items|
      assert_equal [ "Jean Kouassi", "Paul Attente", "Rita Attente", "Awa Bamba", "Sali Commencé", "Moussa Diallo", "Zoé Pas-Encore", "Koffi Yao" ],
                   items.map { it.at_css("a").text }
      assert_select items.first, "svg"
      items.drop(1).each { assert_match(/Pas encore fait/, it.text) }
    end
    [ @pending, started ].each { assert_select "#comprehension_panel ul li a[href='#{file_path(it)}']" }
    assert_select "#comprehension_panel", text: /Parti|Yme/, count: 0
    assert_select "#pending_students, h2#pending_students_title", 0
  end

  # ADR-0079 §4.1: a lacune opened by another exercise of the fiche makes the assigned exercise a remediation; it is done.
  test "a student whose only session on the assignment is a remediation is done, not « pas encore fait »" do
    remediated = create_student(classroom: @classroom, first_name: "Ali", last_name: "Remédié")
    create_exercise_session(student: remediated, exercise: @exercise, status: "completed", classroom_assignment: @assignment,
                            completed_at: Time.zone.local(2026, 10, 7, 10), gap: create_gap(student: remediated, essential: @exercise.essential))
    sign_in_as @teacher

    get follow_up_path

    assert_select "#follow_up_progress span", text: "4 / 5 faits"
    assert_select "#comprehension_panel li", text: /Pas encore fait/, count: 1
    assert_select "#comprehension_panel li", text: /Zoé Pas-Encore\s*Pas encore fait/
    assert_select "#comprehension_panel li", text: /Ali Remédié\s*Fait le 7 oct\./
  end

  test "everybody did it: nobody « Pas encore fait », the counts unchanged" do
    hand_in(@pending, Time.zone.local(2026, 10, 7, 10))
    sign_in_as @teacher

    get follow_up_path

    assert_select "body", text: /Pas encore fait/, count: 0
    assert_select "#comprehension_panel li", 4
    assert_select "#follow_up_progress span", text: "4 / 4 faits"
    assert_select "#follow_up_progress span", text: /en retard/, count: 0
  end

  test "a classroom without any present student: the empty state of the section, no list" do
    classroom = create_classroom(school: @school)
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom:)
    assignment = create_assignment(classroom:, assignable: create_exercise(essential: @exercise.essential), by: @teacher)
    gone = create_student(classroom:, first_name: "Gone", last_name: "Parti")
    hand_in(gone, 1.hour.ago, assignment:)
    Orm::ClassroomStudent.where(student: gone).update_all(left_at: Time.current)
    sign_in_as @teacher

    get classroom_assignment_path(classroom.public_id, assignment.public_id)

    assert_response :success
    assert_select "section#comprehension"
    assert_select "#comprehension_frame" do
      assert_select "p", text: "Personne n'a encore fait cet exercice."
      assert_select "nav, #comprehension_panel", 0
    end
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
      assert_select "#comprehension, #comprehension_frame, #comprehension_panel", 0
      assert_no_match(forbidden_names, response.body)
      assert_no_match(/Badges de la classe|justes|Pas encore fait/, response.body)
      sign_out
    end
  end

  test "a visitor is sent to the sign-in page" do
    get follow_up_path

    assert_redirected_to new_session_path
  end
end
