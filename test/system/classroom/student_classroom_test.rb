require "application_system_test_case"

# CL-22, CL-10 (volet élève) — UDR-0011, UDR-0076 §3.2, UDR-0086 (ma-classe-eleve). L'élève ouvre « Ma classe » depuis le
# menu de l'avatar, sans rechargement de page : plus de retour « Accueil », la carte de la classe sans code, les cours de
# ses exercices assignés en bande défilante, ses devoirs reçus en feuilles, ses exercices traités au meilleur
# score ; sur ordinateur, les assignés à gauche (2/3), les traités à droite (1/3) et « Ma classe » actif dans le menu de gauche.
class Classroom::StudentClassroomTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1440, 900 ].freeze

  setup do
    @classroom = create_classroom(name: "Tle D 1", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    create_teacher(school: @classroom.school, classrooms: [ @classroom ])
    # UDR-0013, amendement du 2026-10-01 : le cours de l'exercice assigné est du niveau et de la série de la classe.
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            level: @classroom.level, series: @classroom.series)
    @essential = create_essential(course: @course)
    (1..4).each do |rank|
      create_assignment(classroom: @classroom, assignable: create_exercise(essential: @essential, title: "Devoir #{rank}"),
                        assigned_at: rank.hours.ago)
    end
    done = create_exercise(essential: @essential, title: "Méiose, le bilan")
    create_exercise_session(student: @student, exercise: done, status: "completed", score_percent: 80)
  end

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def rect(id) = page.evaluate_script("document.getElementById(#{id.to_json}).getBoundingClientRect().toJSON()")

  # CA-1, CA-5 : à 390 px, depuis la carte de l'accueil (Lot D : le bandeau remplace l'en-tête) ; « Ma classe » en surbrillance, ni retour « Accueil » ni barre du bas.
  test "at 390 px, from the home's card: no « Accueil » link, the classroom, one sheet per assigned exercise, the score" do
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
      visit student_home_path
      assert_no_page_reload do
        find("#student_next_step a[href='#{student_classroom_path}']").click
        assert_current_path student_classroom_path
      end

      assert_no_selector "#main nav[aria-label='#{I18n.t('components.back_link.label')}']"
      assert_no_selector "nav.bottom-0"

      within "#student_classroom_header" do
        assert_selector "h2", text: "Tle D 1"
        assert_no_selector "[id*=join_code]"
      end
      within("#student_classroom_courses") { assert_link "Génétique et évolution", href: course_path(@course.slug) }
      within "#student_classroom_treated" do
        assert_link "Méiose, le bilan"
        assert_text "16/20"
      end
      assert_single_primary_action
      assert_list_capped "#student_classroom_treated ul"
      # prepare-interros-cahier, Lot F : chaque exercice assigné seul est un envoi d'un exercice, une feuille « Prépare interros ».
      within "#student_classroom_assigned" do
        assert_selector ".ps-sheet", count: 7
        assert_button I18n.t("catalog.courses.sheets.hand_in"), count: 7
        assert_no_button I18n.t("components.reveal.more")
      end
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    end
  end

  # CA-7, CA-E11 : à 1 440 px, « Exercices assignés » (2/3) et « Exercices traités » (1/3) côte à côte, « Ma classe » actif à gauche.
  test "at 1 440 px, the assigned exercises at 2/3 and the treated ones at 1/3, « Ma classe » active in the left menu" do
    sign_in_as @student

    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit student_classroom_path

      assert_selector "aside a[aria-current=page][href='#{student_classroom_path}']", text: tn(:classroom), visible: true
      assigned = rect("student_classroom_assigned")
      treated = rect("student_classroom_treated")
      assert_in_delta assigned["top"], treated["top"], 1, "les deux listes ne sont pas sur la même ligne"
      assert_operator treated["left"], :>=, assigned["right"], "« Exercices traités » n'est pas à droite"
      assert_in_delta assigned["width"], 2 * treated["width"] + 24, 2, "les colonnes ne sont pas 2/3 – 1/3"
      assert_operator rect("student_classroom")["width"], :<=, 960
    end
  end
end
