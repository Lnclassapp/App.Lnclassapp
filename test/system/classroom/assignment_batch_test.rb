require "application_system_test_case"

# prepare-interros-cahier, Lot E (CA-12, CA-15), UDR feuilles-prepare-interros-et-devoirs §3 (Devoir composé par l'enseignant) : l'enseignant coche
# des exercices dans les feuilles de deux leçons, sa sélection le suit d'une leçon à l'autre, « Envoyer à 3e 1 » crée un envoi sans quitter la page.
class Classroom::AssignmentBatchTest < ApplicationSystemTestCase
  setup do
    @thales = create_course(name: "Thalès")
    @pythagore = create_course(name: "Pythagore", level: @thales.level, material: @thales.material)
    @thales_exercises = Array.new(3) { |n| create_exercise(essential: create_essential(course: @thales), title: "Thalès #{n + 1}") }
    @pythagore_exercises = Array.new(3) { |n| create_exercise(essential: create_essential(course: @pythagore), title: "Pythagore #{n + 1}") }
    @classroom = create_classroom(name: "3e 1", level: @thales.level)
    @teacher = create_teacher(classrooms: [ @classroom ])
    Repositories::Classroom::SessionDaysRepository.new.replace(teacher_id: @teacher.id, classroom_id: @classroom.id, weekdays: [ 1, 4 ],
                                                                at: Time.current)
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"
  def box(exercise) = find("#{frame(exercise)} [role=checkbox]")
  def choose(*exercises) = exercises.each { box(it).click }
  def bar = find("#sheet-batch-bar")
  def storage_key = "lnclass-batch-#{@teacher.id}"

  # CA-12 et CA-15, en un seul parcours (un test système coûte cher : budget du chantier, ADR-0069 §9) : 4 exercices choisis dans deux leçons,
  # un cinquième déjà assigné à la classe.
  test "the teacher ticks exercises in two lessons, the selection follows, « Envoyer à 3e 1 » creates one batch and names the exercise already assigned" do
    already = @pythagore_exercises.last
    create_assignment(classroom: @classroom, assignable: already, by: @teacher)
    sign_in_as @teacher
    visit course_path(@thales.slug)
    assert_no_selector "#sheet-batch-bar", visible: :visible

    choose(*@thales_exercises.first(2))
    assert_selector "[role=checkbox][aria-checked=true]", count: 2
    within(bar) do
      assert_text "2 exercices choisis"
      assert_button "Vider"
      assert_button "Envoyer à 3e 1"
    end

    visit course_path(@pythagore.slug)
    assert_selector "#sheet-batch-bar", text: "2 exercices choisis"
    assert_selector "[role=checkbox][aria-checked=true]", count: 0
    choose(*@pythagore_exercises.first(2), already)
    assert_selector "#sheet-batch-bar", text: "5 exercices choisis"
    page.execute_script("window.lnclassNotReloaded = true")

    within(bar) { click_button "Envoyer à 3e 1" }

    assert_selector "#sheet-batch-status[role=status]", text: "Devoir envoyé à 3e 1 : 4 exercices."
    assert_selector "#sheet-batch-status", text: "Déjà assigné : Pythagore 3."
    assert page.evaluate_script("window.lnclassNotReloaded")
    sent = @thales_exercises.first(2) + @pythagore_exercises.first(2)
    batch = Orm::ClassroomAssignment.where(classroom_id: @classroom.id, status: "active").where.not(batch_public_id: nil)
    assert_equal sent.map(&:id).sort, batch.pluck(:assignable_id).sort
    assert_equal 1, batch.pluck(:batch_public_id).uniq.size
    assert_equal [ Entities::Classroom::SessionDays.new(weekdays: [ 1, 4 ]).next_after(Time.zone.today) ], batch.pluck(:due_on).uniq
    # La sélection est vidée, dans la page et dans le navigateur ; les exercices envoyés passent à « Assigné ».
    assert_selector "[role=checkbox][aria-checked=true]", count: 0
    assert_no_text "exercices choisis"
    assert_no_button "Envoyer à 3e 1"
    assert_nil page.evaluate_script("localStorage.getItem('#{storage_key}')")
    sent.last(2).each { within(frame(it)) { assert_selector "[role=status]", text: "✓ Assigné à 3e 1" } }

    # Dix exercices choisis (préremplis : dix clics coûteraient 10 s) : le onzième est refusé avec sa raison, un second clic décoche, « Vider » vide.
    stored = [ *@pythagore_exercises.first(1).map(&:public_id), *Array.new(9) { |n| "autre#{n}" } ]
    page.execute_script("localStorage.setItem('#{storage_key}', '#{stored.to_json}')")
    page.refresh
    assert_selector "#sheet-batch-bar", text: "10 exercices choisis"
    box(@pythagore_exercises[1]).click
    assert_equal "false", box(@pythagore_exercises[1])["aria-checked"]
    assert_selector "#sheet-batch-bar [role=status]", text: "Choisis entre 1 et 10 exercices."
    box(@pythagore_exercises[0]).click
    assert_selector "#sheet-batch-bar", text: "9 exercices choisis"
    within(bar) { click_button "Vider" }
    assert_no_selector "#sheet-batch-bar", visible: :visible
    assert_nil page.evaluate_script("localStorage.getItem('#{storage_key}')")
  end
end
