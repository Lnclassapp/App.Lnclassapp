require "application_system_test_case"

# prepare-interros-cahier, Lot F (CA-13, 14, 16 ; UDR feuilles-prepare-interros-et-devoirs §3, devoirs reçus) : « Ma classe » lit un
# envoi comme une feuille ; l'élève rend chaque exercice à son enseignant (sans correction avant), lit sa note et sa correction,
# puis le refait pour s'entraîner : la copie refaite n'est plus rattachée au devoir.
class Classroom::AssignedSheetsTest < ApplicationSystemTestCase
  setup do
    @course = create_course(name: "Thalès")
    @notion = create_essential(course: @course, name: "La propriété de Thalès", position: 1, sheet: { "remember" => "Les rapports sont égaux." })
    @classroom = create_classroom(level: @course.level, series: @course.series, name: "3e 1")
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(classrooms: [ @classroom ])
    @devoir = Array.new(3) { |index| create_exercise(essential: @notion, title: "Devoir #{index + 1}", questions: 2) }
    @interro = create_exercise(essential: @notion, title: "Interro", questions: 1)
    @assignments = @devoir.to_h do |exercise|
      [ exercise, create_assignment(classroom: @classroom, assignable: exercise, by: @teacher, batch_public_id: "BATCHDEVOIRXXX", assigned_at: 2.hours.ago) ]
    end
    @alone = create_assignment(classroom: @classroom, assignable: @interro, by: @teacher, assigned_at: 1.hour.ago)
    sign_in_as @student
  end

  def frame(exercise) = "#sheet-exercise-#{exercise.public_id}"

  # La proposition 1 de chaque question est la bonne (fabrique) : « A. ».
  def answer(exercise, right: true)
    within(frame(exercise)) { all(".ps-question").each { |question| question.click_button(right ? "A." : "B.") } }
  end

  def sessions(exercise) = Orm::ExerciseSession.where(student: @student, exercise:, status: "completed")

  # CA-13, CA-14, CA-11 (à 390 px : rien ne dépasse de l'écran, chaque bouton fait 44 px au moins)
  test "« Ma classe » : une feuille par envoi, « Prépare devoirs » dès 3 exercices et « Prépare interros » pour 1 ou 2, sans rien à corriger avant de rendre" do
    with_mobile_viewport do
      visit student_classroom_path

      within "#student_classroom_assigned" do
        assert_selector ".ps-sheet", count: 2
        within(".ps-sheet:first-child") do
          assert_selector ".ps-header-title", text: "PRÉPARE INTERROS", match: :first
          assert_selector ".ps-title", text: "LA PROPRIÉTÉ DE THALÈS"
          assert_selector ".ps-remember", text: "À retenir : Les rapports sont égaux."
          assert_selector ".ps-exercise", count: 1
        end
        within(".ps-sheet:last-child") do
          assert_selector ".ps-header-title", text: "PRÉPARE DEVOIRS", match: :first
          assert_selector ".ps-remember", text: "Notions mobilisées : La propriété de Thalès"
          assert_selector ".ps-exercise", count: 3
          assert_button "Rendre à l'enseignant", count: 3
          assert_no_button "Vérifier ma réponse"
          assert_no_selector ".ps-result"
          assert_no_button "Recommencer"
        end
      end
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      heights = page.evaluate_script("Array.from(document.querySelectorAll('#student_classroom_assigned .ps-btn')).filter((b) => b.offsetParent).map((b) => b.getBoundingClientRect().height)")
      assert_operator heights.min, :>=, 44
    end
  end

  # CA-16
  test "rendre à l'enseignant rattache la copie et montre la note et la correction ; refaire donne une copie d'entraînement non rattachée" do
    first = @devoir.first
    visit student_classroom_path
    address = current_url
    answer(first)

    within(frame(first)) { click_button "Rendre à l'enseignant" }

    within(frame(first)) do
      assert_selector ".ps-result-grade", text: "Ta note : 10 / 10"
      assert_selector ".ps-correction-item", count: 2
      assert_button "Refaire l'exercice"
      assert_no_button "Rendre à l'enseignant"
    end
    assert_equal address, current_url
    assert_equal [ @assignments.fetch(first).id ], sessions(first).pluck(:classroom_assignment_id)
    # Les deux autres exercices du devoir attendent toujours d'être rendus, sans correction.
    within(frame(@devoir.second)) { assert_button "Rendre à l'enseignant"; assert_no_selector ".ps-result" }

    within(frame(first)) { click_button "Refaire l'exercice" }
    answer(first, right: false)
    within(frame(first)) { click_button "Vérifier ma réponse" }

    within(frame(first)) { assert_selector ".ps-result-grade", text: "Ta note : 0 / 10" }
    assert_equal [ @assignments.fetch(first).id, nil ], sessions(first).order(:id).pluck(:classroom_assignment_id)
  end
end
