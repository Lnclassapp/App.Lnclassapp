require "application_system_test_case"

# CL-22, CL-10 (volet élève) — UDR-0011. L'élève ouvre « Ma classe » depuis la navigation : il voit le code de sa classe
# en majuscules et ses cours assignés, puis ouvre l'un d'eux, sans rechargement de page.
class Classroom::StudentClassroomTest < ApplicationSystemTestCase
  setup do
    @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", school: create_school(name: "Lycée Classique"),
                                  level: create_level(name: "Tle"), series: create_series(name: "D"))
    @student = create_student(classroom: @classroom, first_name: "Aya")
    # UDR-0013, amendement du 2026-10-01 : le cours assigné est du niveau et de la série de la classe.
    @course = create_course(name: "Génétique et évolution", material: create_material(name: "SVT", category: "science"),
                            level: @classroom.level, series: @classroom.series)
    create_essential(course: @course)
    create_assignment(classroom: @classroom, assignable: @course)
    create_assignment(classroom: @classroom, assignable: create_course(name: "Écologie"), status: "archived")
  end

  def tl(key, **) = I18n.t("classroom.student_classrooms.#{key}", **)

  test "the student sees their classroom code and assigned courses, then opens a course" do
    sign_in_as @student

    assert_no_page_reload do
      click_on I18n.t("shared.navigation.classroom"), match: :first
      assert_current_path student_classroom_path
    end
    within "#student_classroom_header" do
      assert_selector "h2", text: "Tle D 1"
      assert_selector "#student_classroom_join_code", exact_text: "KFM37"
    end
    assert_selector "#student_classroom_courses li", count: 1
    assert_no_text "Écologie"

    assert_no_page_reload do
      click_on "Génétique et évolution"
      assert_current_path course_path(@course.slug)
      assert_selector "h1", text: "Génétique et évolution"
    end
  end

  # UDR-0011, amendement du 2026-10-02 (UDR-0057) : à 390 px, au plus 5 blocs avant le pli, aucune action principale,
  # 3 cours puis « Voir plus » ; l'aide du code est une infobulle qui s'ouvre au toucher.
  test "at 390 px, Ma classe passes the sobriety rule, reveals the fourth course and opens the code help" do
    %w[Algèbre Biologie Chimie].each do |name|
      create_assignment(classroom: @classroom, assignable: create_course(name:, level: @classroom.level, series: @classroom.series))
    end
    sign_in_as @student

    with_mobile_viewport do
      visit student_classroom_path

      assert_blocks_above_fold "#main > div > div:not(.grid), #main > div > .grid > *", max: 5
      assert_single_primary_action
      within("#student_classroom_courses") do
        assert_list_capped "ul"
        assert_no_text "Génétique et évolution"

        assert_no_page_reload { click_on I18n.t("components.reveal.more") }

        assert_text "Génétique et évolution"
        assert_selector "li", count: 4
        assert_no_button I18n.t("components.reveal.more")
        assert_selector "[role=status]", text: I18n.t("components.reveal.announce_one"), visible: :all
      end

      within("#student_classroom_header") do
        assert_no_text tl("show.join_code_info_tip")
        find("summary", text: I18n.t("components.info_tip.label", label: tl("show.join_code")), visible: :all).click
        assert_text tl("show.join_code_info_tip")
      end
    end
  end
end
