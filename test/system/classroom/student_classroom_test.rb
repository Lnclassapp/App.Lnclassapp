require "application_system_test_case"

# CL-22, CL-10 (volet élève) — UDR-0011. L'élève ouvre « Ma classe » depuis la navigation, sans rechargement de page :
# il voit le code de sa classe en majuscules. ADR-0072, UDR-0011 (amendée le 2026-10-02) : la carte « Cours assignés »
# a disparu, un cours ne s'assignant plus.
class Classroom::StudentClassroomTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours de l'exercice assigné est du niveau et de la série de la classe.
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            level: @classroom.level, series: @classroom.series)
    create_assignment(classroom: @classroom, assignable: create_exercise(essential: create_essential(course: @course)))
  end

  def tl(key, **) = I18n.t("classroom.student_classrooms.#{key}", **)

  test "the student sees their classroom code, and no « Cours assignés » card" do
    sign_in_as @student

    assert_no_page_reload do
      click_on I18n.t("shared.navigation.classroom"), match: :first
      assert_current_path student_classroom_path
    end
    within "#student_classroom_header" do
      assert_selector "h2", text: "Tle D 1"
      assert_selector "#student_classroom_join_code", exact_text: "KFM37"
    end
    assert_no_selector "#student_classroom_courses"
    assert_no_text "Cours assignés"
    assert_no_link "Génétique et évolution"
  end

  # UDR-0011, amendement du 2026-10-02 (UDR-0057) : à 390 px, au plus 5 blocs avant le pli, aucune action principale ;
  # l'aide du code est une infobulle qui s'ouvre au toucher. Plus de liste de cours, donc plus de « Voir plus ».
  test "at 390 px, Ma classe passes the sobriety rule, has nothing to reveal and opens the code help" do
    sign_in_as @student

    with_mobile_viewport do
      visit student_classroom_path

      assert_blocks_above_fold "#main > div > div:not(.grid), #main > div > .grid > *", max: 5
      assert_single_primary_action
      assert_no_button I18n.t("components.reveal.more")
      assert_no_selector "#student_classroom_courses"

      within("#student_classroom_header") do
        assert_no_text tl("show.join_code_info_tip")
        find("summary", text: I18n.t("components.info_tip.label", label: tl("show.join_code")), visible: :all).click
        assert_text tl("show.join_code_info_tip")
      end
    end
  end
end
