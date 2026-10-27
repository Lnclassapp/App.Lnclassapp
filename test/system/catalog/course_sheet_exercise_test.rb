require "application_system_test_case"

# contenu-en-blocs (#318), Lot C — CA-7 et CA-8 : exercices corrigés de la fiche de cours et « Je m'entraîne ».
# La page de la fiche (route course_sheet) est du Lot B : ce test ne passe qu'une fois les deux lots fusionnés.
class Catalog::CourseSheetExerciseTest < ApplicationSystemTestCase
  BANK = [
    { "prompt" => "Calculer 2 + 2.", "answer" => 4, "solution" => "2 + 2 = 4." },
    { "prompt" => "Calculer 3 × 1,5.", "answer" => 4.5, "solution" => "3 × 1,5 = 4,5." }
  ].freeze

  # Un exercice numérique + choix non figé, un choix figé, une banque : ce que la fiche de référence ne couvre pas.
  def document
    exercise = { "type" => "exercise", "title" => "Exercice 4", "prompt" => "Calculer AN et MN.",
                 "fields" => [
                   { "id" => "an", "input" => "numeric", "label" => "AN =", "answer" => 3.6 },
                   { "id" => "mn", "input" => "numeric", "label" => "MN =", "answer" => 4.2 },
                   { "id" => "par", "input" => "choice", "label" => "Les droites sont", "options" => [ "parallèles", "non parallèles" ], "answer" => 0 }
                 ],
                 "hint" => "Écris d'abord les trois rapports.", "correction" => "AN = 3 × 6 ÷ 5 = 3,6 cm." }
    frozen = { "type" => "exercise", "title" => "Exercice 5", "prompt" => "Complète la phrase.",
               "fields" => [ { "id" => "mot", "input" => "choice", "label" => "Connecteur", "options" => [ "car", "pourtant", "donc" ], "answer" => 0, "frozen" => true } ] }
    practice = { "type" => "practice", "kind" => "bank", "title" => "Je m'entraîne", "bank" => BANK }
    { "pages" => [ { "sections" => [ { "title" => "Exercices", "blocks" => [ exercise, frozen, practice ] } ] } ], "glossary" => {} }
  end

  setup do
    level = create_level(name: "3e")
    course = create_course(name: "Propriété de Thalès", level:)
    create_course_sheet(course:, document:)
    @course = course
    sign_in_as create_student(classroom: create_classroom(level:))
    visit course_sheet_path(course.slug)
  end

  def t(key, **) = I18n.t("catalog.course_sheets.#{key}", **)
  def field(id) = find("[data-field-id='#{id}'][data-input]")
  def feedback(id) = find("small[data-field-id='#{id}']", visible: :all)
  def exercise_card(title) = find(".sheet-card", text: title)

  test "Vérifier rend juste, à revoir ou à compléter et le message global" do
    card = exercise_card("Exercice 4")

    within(card) do
      field("an").set("3,6")
      field("mn").set("4,21")
      click_on "parallèles", exact: true
      click_on t("exercise.check")

      assert_equal t("exercise.correct"), feedback("an").text
      assert_equal t("exercise.correct"), feedback("mn").text
      assert_equal t("exercise.correct"), feedback("par").text
      assert_text t("exercise.all_correct")

      field("an").set("3,62")
      assert_no_text t("exercise.all_correct")
      assert_equal "", feedback("an").text
      field("mn").set("")
      click_on t("exercise.check")

      assert_equal t("exercise.wrong"), feedback("an").text
      assert_equal t("exercise.incomplete"), feedback("mn").text
      assert_text t("exercise.some_wrong")
    end
  end

  test "une fraction ou un point décimal sont acceptés, une unité collée est à revoir" do
    within(exercise_card("Exercice 4")) do
      field("an").set("18/5")
      field("mn").set("4.2")
      click_on "non parallèles"
      click_on t("exercise.check")

      assert_equal t("exercise.correct"), feedback("an").text
      assert_equal t("exercise.correct"), feedback("mn").text
      assert_equal t("exercise.wrong"), feedback("par").text

      field("mn").set("4,2 cm")
      click_on t("exercise.check")

      assert_equal t("exercise.wrong"), feedback("mn").text
    end
  end

  test "Indice et Correction se déplient et se replient" do
    within(exercise_card("Exercice 4")) do
      assert_no_text "Écris d'abord les trois rapports."
      click_on t("exercise.hint")

      assert_text "Écris d'abord les trois rapports."
      assert_selector "button[aria-expanded=true]", text: t("exercise.hint")
      click_on t("exercise.correction")

      assert_text "AN = 3 × 6 ÷ 5 = 3,6 cm."
      click_on t("exercise.correction")

      assert_no_text "AN = 3 × 6 ÷ 5 = 3,6 cm."
    end
  end

  test "le choix figé se fige au premier clic" do
    within(exercise_card("Exercice 5")) do
      click_on "pourtant"

      assert_equal t("exercise.wrong"), feedback("mot").text
      assert_selector "button[data-state=wrong]", text: "pourtant"
      assert_selector "button[data-state=right]", text: "car"

      click_on "donc"
      click_on "car"

      assert_equal t("exercise.wrong"), feedback("mot").text
      assert_selector "button[aria-pressed=true]", text: "pourtant"
      assert_no_selector "button[aria-pressed=true]", text: "car"
    end
  end

  test "le choix non figé se corrige jusqu'à Vérifier" do
    within(exercise_card("Exercice 4")) do
      click_on "non parallèles"
      click_on "parallèles", exact: true

      assert_selector "button[aria-pressed=true]", text: "parallèles", exact_text: true
      assert_equal "", feedback("par").text
    end
  end

  test "Je m'entraîne compte le score une fois par énoncé, Entrée vérifie, un nouvel énoncé remplace l'énoncé" do
    practice = find(".sheet-practice")

    within(practice) do
      assert_text t("practice.score", ok: 0, total: 0)

      first = find("[data-course-sheet--practice-target=prompt]").text
      answer = BANK.find { it["prompt"] == first }.fetch("answer").to_s.tr(".", ",")
      find("input").set(answer)
      find("input").send_keys(:enter)

      assert_text t("practice.score", ok: 1, total: 1)
      click_on t("practice.check")
      click_on t("practice.check")

      assert_text t("practice.score", ok: 1, total: 1)

      click_on t("practice.solution")

      assert_text BANK.find { it["prompt"] == first }.fetch("solution")

      click_on t("practice.next")

      assert_no_text first
      assert_no_text BANK.find { it["prompt"] == first }.fetch("solution")
      assert_equal "", find("input").value
      assert_text t("practice.score", ok: 1, total: 1)

      second = find("[data-course-sheet--practice-target=prompt]").text
      find("input").set("0")
      click_on t("practice.check")
      click_on t("practice.check")

      assert_text t("practice.score", ok: 1, total: 2)
      assert_not_equal first, second
    end
  end

  test "un champ vide ne compte pas dans le score" do
    within(find(".sheet-practice")) do
      click_on t("practice.check")

      assert_text t("exercise.incomplete")
      assert_text t("practice.score", ok: 0, total: 0)
    end
  end
end
