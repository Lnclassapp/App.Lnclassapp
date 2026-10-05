require "application_system_test_case"

# Challenger of remediation-comptee-faite (bugfix, phase 5): the memo's reproduction, replayed in the browser. In 3ème B,
# Aya fails X at 33 % in the interface, which opens a gap on the fiche (ADR-0043); she then starts Y, which opens a
# remediation session on Y's assignment, and passes it at 100 %. The school management opens the 3ème level from its home,
# then 3ème B: Y is handed in and its 100 % is in the averages. A remediation started but not finished, and a student of
# another classroom, change nothing to the figures of 3ème B. The rest of the classroom is set up by the factories.
# The memo's 25 % and 80 % need 9 questions to play; 3 and 2 keep the scenario within the system budget (≤ 10 s).
class SchoolAdmin::RemediationHandedInTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT
  SESSION = "assessment.exercise_sessions".freeze

  setup do
    school = create_school(name: "Collège Moderne de Daloa")
    @admin = create_school_admin(school:, first_name: "Adjoua")
    level = create_level(name: "3ème", position: 4, cycle: "first")
    @essential = create_essential(course: create_course(level:, name: "Génétique"), name: "La méiose")
    @x = create_exercise(essential: @essential, title: "Méiose X", questions: 3)
    @y = create_exercise(essential: @essential, title: "Méiose Y", questions: 2)
    teacher = create_teacher(school:)

    @klass = create_classroom(school:, level:, name: "3ème B")
    @given_x, @given_y = [ @x, @y ].map { create_assignment(classroom: @klass, assignable: it, by: teacher) }
    @aya = create_student(classroom: @klass, first_name: "Aya", last_name: "Bamba")
    # The classroom average shows from 5 students who handed in: four classmates hand X in at 60 %.
    4.times do |index|
      classmate = create_student(classroom: @klass, first_name: "Élève", last_name: "Zz#{index}")
      create_exercise_session(student: classmate, exercise: @x, status: "completed", score_percent: 60,
                              classroom_assignment_id: @given_x.id)
    end
    # Error path 1: Moussa has a gap on the fiche (from an unassigned exercise) and has only started Y in remediation.
    moussa = create_student(classroom: @klass, first_name: "Moussa", last_name: "Coulibaly")
    create_exercise_session(student: moussa, exercise: @y, classroom_assignment_id: @given_y.id,
                            gap: create_gap(student: moussa, essential: @essential))

    # Error path 2: Koffi, of 3ème A, does Y in remediation for his own classroom, and a stray remediation session of his
    # carries the id of 3ème B's assignment: neither moves 3ème B.
    @other = create_classroom(school:, level:, name: "3ème A")
    koffi = create_student(classroom: @other, first_name: "Koffi", last_name: "Diallo")
    koffi_gap = create_gap(student: koffi, essential: @essential)
    given_y_other = create_assignment(classroom: @other, assignable: @y, by: teacher)
    [ given_y_other, @given_y ].each do |given|
      create_exercise_session(student: koffi, exercise: @y, status: "completed", score_percent: 100, gap: koffi_gap,
                              classroom_assignment_id: given.id)
    end
  end

  test "memo: Y done in remediation is handed in and counts in the averages; started or foreign sessions do not" do
    sign_in_as @aya
    assert_selector "main#main", wait: SIGN_IN_WAIT

    play(@x, rights: 1) # 1 / 3 : 33 % (the score is truncated)
    failed = Orm::ExerciseSession.find_by!(student: @aya, exercise: @x)
    assert_equal [ "completed", 33, "standard", @given_x.id ], failed.values_at(:status, :score_percent, :kind, :classroom_assignment_id)
    gap = Orm::KnowledgeGap.find_by!(student: @aya, essential: @essential)
    assert_equal [ "pending", failed.id ], gap.values_at(:status, :source_session_id), "X raté : une lacune en attente sur la fiche"

    play(@y, rights: 2) do |session| # 2 / 2 : 100 %
      assert_equal [ "started", "remediation", gap.id, @given_y.id ],
                   session.values_at(:status, :kind, :knowledge_gap_id, :classroom_assignment_id), "Y démarre en remédiation"
    end
    assert_equal [ "completed", 100 ], Orm::ExerciseSession.find_by!(student: @aya, exercise: @y).values_at(:status, :score_percent)

    sign_out
    sign_in_as @admin
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path school_admin_classrooms_path
    find("#level_3eme").click
    assert_current_path school_admin_level_path("3eme")

    # 3ème B: 6 students × 2 assignments; handed in: Aya 2, four classmates 1 → 6 / 12 = 50 %.
    # Average of the handed-in sessions: (33 + 100 + 4 × 60) / 6 = 62,2 → 62 %. Before the fix: 5 / 12 = 42 %, 273 / 5 = 55 %.
    assert_equal [ "6 élèves", "2 devoirs donnés", "Taux de rendu : 50 %", "Moyenne : 62 %" ], figures(@klass)
    # 3ème A: Koffi's remediation counts for his own classroom; fewer than 5 students handed in, no average.
    other = figures(@other)
    assert_equal [ "1 élève", "1 devoir donné", "Taux de rendu : 100 %" ], other.first(3)
    assert_match(/\AMoyenne : —/, other.last)

    find("#classroom_#{@klass.public_id} a").click

    assert_current_path school_admin_classroom_path(@klass.public_id)
    assert_equal [ "2", "50 %", "62 %" ], all("#classroom_figures li > span:first-child").map(&:text)
    rows = all("#classroom_students tbody tr").to_h { |row| row.all("th, td").map(&:text).then { [ it.first, it.drop(1) ] } }
    assert_equal [ "2 / 2", "67 %" ], rows.fetch("Aya Bamba"), "Y rendu ; (33 + 100) / 2 = 66,5 → 67 %"
    assert_equal "0 / 2", rows.fetch("Moussa Coulibaly").first, "une remédiation commencée, non terminée, n'est pas rendue"
    assert_match(/\A—/, rows.fetch("Moussa Coulibaly").last)
    assert_equal 6, rows.size
    assert_no_text "Koffi"
  end

  private

  # From the exercise page, « Commencer l'exercice », then each question in turn: the first `rights` answers are right,
  # the others wrong. The block receives the session just started.
  def play(exercise, rights:)
    visit exercise_path(exercise.public_id)
    click_on I18n.t("assessment.exercises.student_progress.start")
    assert_current_path %r{\A/sessions/[^/]+\z}
    session = Orm::ExerciseSession.find_by!(public_id: current_path.split("/").last)
    yield session if block_given?

    count = exercise.questions.count
    count.times do |index|
      within("#question-card") do
        assert_text "Question #{index + 1}"
        choose(index < rights ? "Proposition 1" : "Proposition 2")
        click_on I18n.t("#{SESSION}.question_card.submit")
      end
      assert_selector "#feedback-card"
      click_on I18n.t("#{SESSION}.feedback_card.next") if index < count - 1
    end
    assert_link I18n.t("#{SESSION}.feedback_card.result")
  end

  # The figures of a classroom's card, on the page of its level.
  def figures(classroom) = find("#classroom_#{classroom.public_id}").all("ul > li").map { it.text.squish }
end
