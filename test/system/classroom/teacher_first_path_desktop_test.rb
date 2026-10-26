require "application_system_test_case"

# CA-L5, CA-L6, CA-L7 (UDR enseignant §3.13, « Sur ordinateur ») : à 1280 px, les niveaux sur deux colonnes avec « Terminer » à
# droite et « Mes classes » actif ; la colonne « Exercices » de la fiche reste visible au défilement ; « Assigner » sans jours
# de séance ouvre une modale centrée qu'Échap ferme sans rien écrire, le focus revenant sur « Assigner ».
class Classroom::TeacherFirstPathDesktopTest < ApplicationSystemTestCase
  setup { page.current_window.resize_to(1280, 900) }
  teardown { page.current_window.resize_to(1400, 1400) }

  def rect(selector) = page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { top: r.top, left: r.left, right: r.right, width: r.width } })()")

  test "declaring: levels on two columns, « Terminer » 15 rem on the right, « Classes » active" do
    school = create_school
    levels = [ create_level(name: "6ème", position: 1, cycle: "first"), create_level(name: "5ème", position: 2, cycle: "first") ]
    levels.each { |level| create_classroom(school:, level:, name: "#{level.name} 1") }
    sign_in_as create_teacher(school:, onboarded: false)

    assert_selector "h1", text: I18n.t("classroom.teaching_selections.index.title")
    assert_selector "nav [aria-current='page']", text: "Classes"
    cards = all("main h2").map { |h| h.find(:xpath, "ancestor::div[contains(@class,'break-inside-avoid')]") }
    assert_equal 2, cards.size
    assert_operator cards.last.rect.x, :>, cards.first.rect.x + cards.first.rect.width / 2, "les niveaux ne sont pas sur deux colonnes"
    finish = rect("#teacher-onboarding-form button")
    assert_in_delta 240, finish["width"], 1
    assert_in_delta rect("#teacher-onboarding-form")["right"], finish["right"], 1
  end

  test "course sheet: the « Exercices » column stays visible, the centred days modal closes on Escape" do
    school = create_school
    tle = create_level(name: "Tle")
    course = create_course(name: "Génétique", level: tle, series: create_series(name: "D"), material: create_material(name: "SVT", category: "science"))
    essential = create_essential(course:, name: "Méiose")
    exercise = create_exercise(essential:, title: "Les phases")
    teacher = create_teacher(school:, classrooms: [ create_classroom(school:, level: tle, series: course.series, name: "Tle D 1") ])
    sign_in_as teacher

    visit course_essential_path(course.slug, essential.slug)
    assert_selector "#essential_exercises"
    page.execute_script("document.getElementById('essential_header').style.height = '3000px'")
    page.execute_script("window.scrollTo(0, 1500)")
    sleep 0.3
    box = rect("#essential_exercises")
    assert_in_delta 32, box["top"], 2, "la colonne « Exercices » ne reste pas visible"
    assert_in_delta 380, box["width"], 2

    page.execute_script("window.scrollTo(0, 0)")
    trigger = find("#assignment_#{teacher.classrooms.first.public_id}_Exercise_#{exercise.public_id} a", text: "Assigner") rescue find("a", text: "Assigner")
    trigger.click
    assert_selector "turbo-frame#modal dialog[open]"
    dialog = rect("turbo-frame#modal dialog[open]")
    assert_in_delta 480, dialog["width"], 2
    assert_operator dialog["top"], :>, 0, "la fenêtre est collée en haut, pas centrée"
    assert_in_delta 640, dialog["left"] + dialog["width"] / 2, 2

    find("body").send_keys(:escape)
    assert_no_selector "turbo-frame#modal dialog[open]"
    assert_equal 0, Orm::ClassroomAssignment.count
    assert_equal "Assigner", page.evaluate_script("document.activeElement.textContent.trim()")
  end
end
