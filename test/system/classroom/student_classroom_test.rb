require "application_system_test_case"

# CL-22, CL-10 (volet élève) — UDR-0011, UDR-0076 §3.2. L'élève ouvre « Ma classe » depuis la navigation, sans
# rechargement de page : le code de sa classe en majuscules, les cours de ses exercices assignés en bande défilante,
# 3 exercices assignés puis « Voir plus », ses exercices traités au meilleur score.
class Classroom::StudentClassroomTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours de l'exercice assigné est du niveau et de la série de la classe.
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            level: @classroom.level, series: @classroom.series)
    @essential = create_essential(course: @course)
    (1..4).each do |rank|
      create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title: "Exercice #{rank}"),
                        assigned_at: rank.hours.ago)
    end
    done = create_exercise(essential: @essential, title: "Méiose, le bilan")
    create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 80)
  end

  def tl(key, **) = I18n.t("classroom.student_classrooms.#{key}", **)

  test "the student sees their classroom without code, the course band, 3 assigned exercises then « Voir plus », and their score" do
    sign_in_as @student

    assert_no_page_reload do
      click_on I18n.t("shared.navigation.classroom"), match: :first
      assert_current_path student_classroom_path
    end
    within "#student_classroom_header" do
      assert_selector "h2", text: "Tle D 1"
      assert_no_selector "[id*=join_code]"
    end
    within("#student_classroom_courses") { assert_link "Génétique et évolution", href: course_path(@course.slug) }
    within "#student_classroom_treated" do
      assert_link "Méiose, le bilan"
      assert_text "16/20"
    end
    within "#student_classroom_assigned" do
      assert_selector "li", count: 3
      assert_no_text "Exercice 4"
      click_on I18n.t("components.reveal.more")
      assert_selector "li", count: 4
      assert_text "Exercice 4"
    end
  end

  # UDR-0011 (UDR-0057), UDR-0076 §3.2 : à 390 px, aucune action principale, chaque liste à 3 lignes au plus, aucune
  # page qui défile en largeur (seule la bande des cours défile) ; l'aide du code s'ouvre au toucher.
  test "at 390 px, Ma classe passes the sobriety rule and opens the code help" do
    # Challenger : avec trois cours, la bande élargissait toute la page (485 px pour 390) ; seule la bande doit défiler.
    # Audit ux-pages-eleve (2026-10-06) : un titre d'exercice réel, tronqué sur une ligne, l'élargissait aussi (611 px).
    create_assignment(classroom: @classroom, assigned_at: 1.minute.ago, assignable: create_exercise(
      essential: @essential, title: "Appliquer — Calculer des limites et lever une indétermination dans une fonction rationnelle"
    ))
    [ %w[Fonctions Mathématiques], %w[Électricité Physique-Chimie] ].each do |name, material|
      course = create_course(name:, material: create_material(name: material), level: @classroom.level, series: @classroom.series)
      create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course:)))
    end
    sign_in_as @student

    with_mobile_viewport do
      visit student_classroom_path

      assert_single_primary_action
      assert_list_capped "#student_classroom_assigned ul"
      assert_list_capped "#student_classroom_treated ul"
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end
end
