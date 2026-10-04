require "application_system_test_case"

# FU-10, FU-21, FU-49 (UDR-0054, UDR-0052, UDR-0072): on a classroom's page, the school management opens the help of « Taux
# de rendu » with one touch; from its home it opens a level, then a classroom, searches a student while typing, then comes
# back to the level by the common back link.
module Finitions
  class SchoolAdminTest < ApplicationSystemTestCase
    SIGN_IN_WAIT = SystemAuthenticationHelper::SIGN_IN_WAIT

    setup do
      school = create_school(name: "Lycée Moderne de Bouaké")
      @admin = create_school_admin(school:)
      level = create_level(name: "2nde", position: 5)
      @classroom = create_classroom(school:, level:, name: "2nde C 1")
      create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
      create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
      create_student(classroom: create_classroom(school:, level:, name: "2nde C 2"), first_name: "Awa", last_name: "Touré")
    end

    def tc(key, **) = I18n.t("school_admin.classrooms.#{key}", **)

    test "FU-21: the help of « Taux de rendu » opens with one touch under its figure, on a 390 px phone" do
      with_mobile_viewport do
        sign_in_as @admin
        assert_selector "#direction_home_school", wait: SIGN_IN_WAIT
        visit school_admin_classroom_path(@classroom.public_id)
        assert_title "2nde C 1 · Direction · Lnclass"
        assert_no_text tc("tips.submission_rate")

        summary = find("#classroom_figures summary", text: "Aide : #{tc('show.figures.submission_rate')}", visible: :all)
        summary.click

        assert_text tc("tips.submission_rate")
        assert summary.find(:xpath, "..")[:open], "the details element announces its open state"
        assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=,
                        page.evaluate_script("document.documentElement.clientWidth")
      end
    end

    test "FU-49, FU-10: the school management searches a student of the classroom, then returns to its level" do
      sign_in_as @admin
      assert_selector "#direction_home_school", wait: SIGN_IN_WAIT
      find("#level_2nde").click
      assert_selector "h1", text: "2nde"
      click_link "2nde C 1"
      assert_selector "h1", text: "2nde C 1"
      assert_title "2nde C 1 · Direction · Lnclass"
      assert_equal school_admin_level_path("2nde"), URI(first("main a")[:href]).path
      assert_no_button tc("show.search.submit")

      fill_in tc("show.search.label"), with: "awa"

      assert_selector "#student_work_students [aria-live=polite]", text: tc("show.search.count", count: 1)
      within("#student_work_students tbody") do
        assert_selector "tr", count: 1
        assert_selector "th", text: "Awa Bamba"
      end
      assert_no_text "Touré"
      assert_current_path school_admin_classroom_path(@classroom.public_id, q: "awa")
      assert_field tc("show.search.label"), with: "awa", focused: true

      fill_in tc("show.search.label"), with: ""

      assert_selector "#student_work_students tbody tr", count: 2

      within("main nav[aria-label='#{I18n.t('components.back_link.label')}']") { click_link "2nde" }

      assert_current_path school_admin_level_path("2nde")
      assert_selector "h1", text: "2nde"
    end
  end
end
