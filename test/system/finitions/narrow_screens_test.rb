require "application_system_test_case"

# Finitions UX, Lot Z (UDR-0054 §3.11, §3.12): at 390 px, no screen touched by the chantier scrolls sideways, info tips
# open (FU-53, FU-23 for the steering page), the living style guide included; the old copy controller is gone (FU-54).
module Finitions
  class NarrowScreensTest < ApplicationSystemTestCase
    TIP = /#{Regexp.escape(I18n.t("components.info_tip.label", label: ""))}/

    setup do
      seed_referential
      @school = create_school(name: "Lycée moderne de Cocody")
      @classroom = create_classroom(school: @school, name: "3e A")
      @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
      create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
      @course = create_course(name: "Génétique et évolution")
    end

    def no_horizontal_scroll? = evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")

    # Every info tip of the page opened, then the page measured.
    def assert_fits(label)
      assert_selector "main", visible: :all
      all("summary", text: TIP, visible: :all).each { it.click if it.visible? }
      assert no_horizontal_scroll?, "#{label} défile en largeur à 390 px"
    end

    def assert_pages_fit(paths)
      with_mobile_viewport do
        paths.each do |path|
          visit path
          assert_fits path
        end
      end
    end

    test "FU-53: the public pages fit at 390 px" do
      assert_pages_fit [ root_path, new_session_path, new_join_code_path, join_classroom_path(@classroom.join_code),
                         new_teacher_registration_path, new_pending_teacher_registration_path, new_identity_pin_reset_path ]
    end

    test "FU-53, FU-23: the team screens fit at 390 px, info tips open" do
      sign_in_as create_team_member

      assert_pages_fit [ team_home_path, levels_path, series_index_path, materials_path, drenas_path, classroom_plan_path,
                         schools_path, school_path(@school.public_id), classroom_path(@classroom.public_id), team_dashboard_path,
                         teams_growth_path, teams_account_lookup_path, teams_imports_path, courses_path, profile_path ]
    end

    test "FU-53: the teacher screens fit at 390 px, info tips open" do
      sign_in_as @teacher

      assert_pages_fit [ teacher_home_path, classroom_path(@classroom.public_id), teacher_invite_path, teacher_classrooms_path,
                         courses_path, course_path(@course.slug), course_assignments_path(@course.slug) ]
    end

    test "FU-53: the school admin screens fit at 390 px, info tips open" do
      sign_in_as create_school_admin(school: @school)

      assert_pages_fit [ school_admin_classrooms_path, school_admin_classroom_path(@classroom.public_id), school_admin_teachers_path ]
    end

    # The API line of the toasts (`flash[:notice|…]`, without a space) used to widen the page (journal, Lot 0).
    test "FU-53: the living style guide fits at 390 px" do
      with_mobile_viewport do
        visit design_path
        assert_selector "section#finishes"
        assert no_horizontal_scroll?, "/design défile en largeur à 390 px"
      end
    end

    test "FU-54: the old copy controller is not registered any more, the common one is" do
      visit new_session_path

      assert evaluate_script("window.Stimulus.router.modulesByIdentifier.has('clipboard')")
      assert_not evaluate_script("window.Stimulus.router.modulesByIdentifier.has('classroom--join-code-copy')")
    end
  end
end
