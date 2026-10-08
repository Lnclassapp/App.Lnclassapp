require "application_system_test_case"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): no automatic anonymization. At 390 px, a student whose classroom
# was archived signs in, lands on his home without a classroom (ADR-0085 §4.3: no more waiting screen for a student) and
# opens « Voir mon historique »: his classrooms and his finished exercises, 3 lines then « Voir plus », under the
# sobriety rule (UDR-0057).
class Classroom::StudentArchiveTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

  setup do
    classroom = create_classroom(name: "3ème 4", level: create_level(name: "3ème"), school: create_school(name: "Lycée Moderne de Bouaké"),
                                 status: "archived", school_year: "2025-2026")
    @student = create_student(classroom:, first_name: "Awa")
    course = create_course(material: create_material(name: "Mathématiques", category: "science"))
    essential = create_essential(course:)
    # Audit ux-pages-eleve (2026-10-06) : un titre réel, tronqué sur une ligne, élargissait la page (583 px pour 390).
    [ "Fractions", "Équations", "Statistiques — Lire et interpréter un diagramme en boîte sur deux séries", "Géométrie" ]
      .each_with_index do |title, index|
      create_exercise_session(student: @student, exercise: create_exercise(essential:, title:), status: "completed",
                              score_percent: 60, completed_at: Time.zone.local(2026, 3, 10 + index, 10))
    end
  end

  def assert_no_horizontal_scroll
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                    page.evaluate_script("document.documentElement.clientWidth")
  end

  def t(key, **) = I18n.t(key, **)

  test "at 390 px, the student who left reads his archive from his home without a classroom, without a page reload" do
    with_mobile_viewport do
      sign_in_as @student
      # ADR-0085 §4.3 (Lot F) : sans classe active, l'élève arrive sur son accueil, « Choisis ta classe » et son historique.
      assert_selector "#student_home_no_classroom", text: t("classroom.student_homes.no_classroom.title"), wait: SIGN_IN_WAIT
      assert_single_primary_action

      assert_no_page_reload do
        click_on t("classroom.student_homes.no_classroom.archive")
        assert_current_path student_archive_path
        assert_selector "h1", text: t("classroom.student_archives.show.title")
      end

      within("#student_archive_classrooms") { assert_text "3ème 4" }
      assert_blocks_above_fold "#main > div > div:not(.grid), #main > div > .grid > *", max: 5
      assert_single_primary_action
      assert_no_horizontal_scroll
      within("#student_archive_results") do
        assert_list_capped "ul"
        assert_text "Géométrie"
        assert_no_text "Fractions"

        assert_no_page_reload { click_on t("components.reveal.more") }

        assert_text "Fractions"
        assert_selector "li", text: "12/20", count: 4
      end
    end
  end
end
