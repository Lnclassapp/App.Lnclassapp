require "application_system_test_case"

# Lot R of fonctions-espace-eleve (ADR-0036, memo Q19): no automatic anonymization. At 390 px, a student whose classroom
# was archived signs in, lands on his home without a classroom (ADR-0085 §4.3: no more waiting screen for a student) and
# opens « Voir mon historique »: his classrooms and his finished exercises, 3 lines then « Voir plus », under the
# sobriety rule (UDR-0057). Redesigned by historique-eleve (UDR-0090): the blue card of the total, then the exercises
# by month, a month heading appearing with its first revealed row; from 1 024 px, exercises on the left, classrooms on
# the right.
class Classroom::StudentArchiveTest < ApplicationSystemTestCase
  SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze

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
    create_exercise_session(student: @student, exercise: create_exercise(essential:, title: "Proportionnalité"),
                            status: "completed", score_percent: 80, completed_at: Time.zone.local(2026, 2, 20, 10))
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
      assert_selector "#student_next_step", text: t("classroom.student_homes.no_classroom.title"), wait: SIGN_IN_WAIT
      assert_single_primary_action

      assert_no_page_reload do
        click_on t("classroom.student_homes.no_classroom.archive")
        assert_current_path student_archive_path
        assert_selector "h1", text: t("classroom.student_archives.show.title")
      end

      # CA-2 : la carte bleue donne le total.
      assert_selector "#student_archive_summary", text: /5\s+exercices terminés/i
      within("#student_archive_classrooms") { assert_text "3ème 4" }
      assert_blocks_above_fold "#student_archive > div:not(.grid), #student_archive > .grid > *", max: 5
      assert_single_primary_action
      assert_no_horizontal_scroll
      within("#student_archive_results") do
        assert_list_capped "[data-controller=reveal]"
        # CA-3 : un titre par mois ; celui de février suit sa ligne, encore masquée.
        assert_selector "h3", text: /mars 2026/i, count: 1
        assert_no_selector "h3", text: /février 2026/i
        assert_text "Géométrie"
        assert_no_text "Fractions"

        assert_no_page_reload { click_on t("components.reveal.more") }

        assert_text "Fractions"
        assert_selector "h3", text: /février 2026/i
        assert_selector "li", text: "12/20", count: 4
        assert_selector "li", text: "16/20", count: 1
      end
      assert_no_horizontal_scroll
    end
  end

  # CA-6 : dès 1 024 px, « Mes exercices terminés » à gauche, en grand, et « Mes classes » à droite, sous la carte bleue.
  test "at 1 280 px, the finished exercises are on the left and the classrooms on the right, under the blue card" do
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      sign_in_as @student
      assert_selector "#student_next_step", wait: SIGN_IN_WAIT
      visit student_archive_path

      summary, results, classrooms = %w[summary results classrooms].map do |part|
        page.evaluate_script("document.getElementById('student_archive_#{part}').getBoundingClientRect().toJSON()")
      end

      assert_operator results["right"], :<, classrooms["left"]
      assert_in_delta results["top"], classrooms["top"], 1
      assert_operator summary["bottom"], :<=, results["top"]
      assert_operator results["width"], :>, classrooms["width"] * 1.5
      assert_no_horizontal_scroll
    end
  end
end
