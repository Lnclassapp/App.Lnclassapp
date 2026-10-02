require "application_system_test_case"

# Finitions UX, Lot F — UDR-0054, UDR-0011, UDR-0013, UDR-0015, UDR-0021, UDR-0023. Le catalogue se cherche par nom
# pendant la frappe, sans accents (FU-47) ; la page cours n'a plus qu'un retour « Cours » (FU-14) ; l'accueil élève a son
# titre (FU-02) ; badges et maîtrise ont leur infobulle ; « Ma classe » n'a toujours pas de « Copier » (FU-27) ; rien ne
# défile en largeur à 390 px (FU-53).
module Finitions
  class CatalogAndStudentTest < ApplicationSystemTestCase
    setup do
      @tle = create_level(name: "Tle", position: 7)
      @svt = create_material(name: "SVT", category: "science")
      @maths = create_material(name: "Maths", category: "science")
      @course = create_course(name: "Génétique et évolution", level: @tle, material: @svt)
      @mathematiques = create_course(name: "Mathématiques 3e", level: @tle, material: @maths)
      create_course(name: "La cellule", level: @tle, material: @svt)
      @essential = create_essential(course: @course, name: "La méiose")
      @exercise = create_exercise(essential: @essential, title: "Méiose et ADN")
      # UDR-0013, amendement du 2026-10-01 : la classe de l'élève est de Tle, le niveau des cours du catalogue.
      @classroom = create_classroom(name: "Tle D 1", join_code: "kfm37", level: @tle)
      @student = create_student(classroom: @classroom, first_name: "Aya")
      create_assignment(classroom: @classroom, assignable: @essential)
    end

    def t(key, **) = I18n.t(key, **)
    def tc(key, **) = t("catalog.courses.index.#{key}", **)
    def search_field = find_field(tc("filters.search"))
    def history_length = page.evaluate_script("history.length")

    def completed_session(score_percent: 80)
      create_exercise_session(student: @student, exercise: @exercise, status: "completed", score_percent:).tap do |session|
        create_badge(student: @student, exercise: @exercise, level: "gold", session:)
      end
    end

    def assert_info_tip(label, text)
      tip = find("summary", text: t("components.info_tip.label", label:), visible: :all)
      assert_no_text text
      tip.click
      assert_text text
    end

    def assert_no_horizontal_scroll(where)
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "#{where} défile en largeur"
    end

    test "FU-47 : le catalogue se cherche pendant la frappe, sans accents, et l'état vide propose d'effacer la recherche" do
      sign_in_as @student
      visit courses_path
      assert_selector "#courses_list > li", count: 3
      assert_no_button tc("filters.submit")
      before = history_length

      assert_no_page_reload do
        # Un seul caractère ne part pas : « m » ne garderait que « Mathématiques 3e ».
        search_field.fill_in with: "m"
        sleep 0.6
        assert_selector "#courses_list > li", count: 3

        search_field.fill_in with: "mathematiques"
        assert_selector "#courses_list > li", count: 1
        assert_selector "#courses_list", text: "Mathématiques 3e"
        assert_selector "#courses_total", text: tc("total", count: 1)
        assert_current_path(/q=mathematiques/)
        assert_equal before, history_length, "la frappe empile l'historique"
        assert_equal "mathematiques", search_field.value

        search_field.fill_in with: "zzz"
        within "#courses_empty" do
          assert_text tc("no_match_title")
          assert_link tc("clear_search"), href: courses_path
        end

        search_field.fill_in with: ""
        assert_selector "#courses_list > li", count: 3

        select "Maths", from: tc("filters.material")
        assert_selector "#courses_list > li", count: 1
        assert_current_path(/material=#{@maths.slug}/)
      end

      click_on tc("filters.reset")
      assert_selector "#courses_list > li", count: 3
      assert_equal "", search_field.value
    end

    test "FU-14 : sur la page d'un cours, le seul retour est « Cours », vers le catalogue" do
      sign_in_as @student
      visit course_path(@course.slug)

      assert_title "Génétique et évolution · Élève · Lnclass"
      within "main" do
        assert_selector "nav", count: 1
        assert_selector "nav[aria-label='#{t('components.back_link.label')}'] a[href='#{courses_path}']",
                        text: t("catalog.courses.show.back")
        assert_no_link "SVT"
      end
      within("main nav") { click_on t("catalog.courses.show.back") }
      assert_current_path courses_path
      assert_title "Cours · Élève · Lnclass"
    end

    # UDR-0058 §3.3 (R4) : l'aide « Badges » / « Maîtrise » quitte l'accueil ; la page de l'exercice les explique.
    test "FU-02 : l'accueil élève s'appelle « Accueil · Élève · Lnclass », sans aide affichée en permanence" do
      completed_session
      sign_in_as @student

      assert_current_path student_home_path
      assert_title "Accueil · Élève · Lnclass"
      within("#student_home_exercises") { assert_no_selector "#student_home_help" }
    end

    test "FU-27 : « Ma classe » montre le code de la classe sans bouton « Copier »" do
      sign_in_as @student
      visit student_classroom_path

      assert_title "Ma classe · Élève · Lnclass"
      assert_selector "#student_classroom_join_code", exact_text: "KFM37"
      assert_no_selector "button, a", text: /Copier/, visible: :all
      assert_no_selector "[data-controller~=clipboard]", visible: :all
    end

    test "la fiche, l'exercice, la session et le résultat ont leur titre, leur retour et les infobulles des seuils" do
      session = completed_session
      sign_in_as @student

      visit course_essential_path(@course.slug, @essential.slug)
      assert_title "La méiose · Élève · Lnclass"
      click_on "Génétique et évolution"
      assert_current_path course_path(@course.slug)

      visit course_essential_path(@course.slug, @essential.slug)
      within("#essential_exercises") { assert_info_tip t("catalog.essentials.show.badges_help"), t("shared.info_tips.badges") }

      visit exercise_path(@exercise.public_id)
      assert_title "Méiose et ADN · Élève · Lnclass"
      within "#student_progress" do
        assert_info_tip t("assessment.exercises.student_progress.mastery"), t("shared.info_tips.mastery")
        assert_info_tip t("assessment.exercises.student_progress.badge"), t("shared.info_tips.badges")
      end
      click_on "La méiose", match: :first
      assert_current_path course_essential_path(@course.slug, @essential.slug)

      visit exercise_session_result_path(session.public_id)
      assert_title "Résultat de Méiose et ADN · Élève · Lnclass"
      assert_link "La méiose", href: course_essential_path(@course.slug, @essential.slug)
      assert_info_tip t("assessment.session_results.show.mastery"), t("shared.info_tips.mastery")
      within("#session_badge") { assert_info_tip t("assessment.session_results.badge.help"), t("shared.info_tips.badges") }

      started = create_exercise_session(student: @student, exercise: @exercise)
      visit exercise_session_path(started.public_id)
      assert_title "Méiose et ADN · Élève · Lnclass"
      assert_link t("assessment.exercise_sessions.show.quit"), href: exercise_path(@exercise.public_id)
    end

    test "FU-53 : à 390 px, le catalogue avec sa recherche, les pages de l'élève et les infobulles ne débordent pas" do
      session = completed_session
      sign_in_as @student

      with_mobile_viewport do
        visit courses_path
        search_field.fill_in with: "genetique"
        assert_selector "#courses_list > li", count: 1
        assert_no_horizontal_scroll "le catalogue avec sa recherche"

        [ course_path(@course.slug), student_home_path, student_classroom_path, exercise_path(@exercise.public_id),
          exercise_session_result_path(session.public_id) ].each do |path|
          visit path
          assert_selector "h1"
          all("summary", text: /#{t('components.info_tip.label', label: '')}/, visible: :all).each(&:click)
          assert_no_horizontal_scroll path
        end
      end
    end
  end
end
