require "application_system_test_case"

# Finitions UX, Lot Z — the two gaps left by the lots (journal, Lots A, B, E, F, G, D1):
# - UDR-0054 §3.3: after a 422 re-rendered by morphing (the page) or in the « modal » frame (a modal), the focus goes
#   to the first field in error, even when the form was sent by a click on its button;
# - UDR-0054 §3.9: a search whose answer is not a 2xx shows the error state in its frame, with « Réessayer ».
module Finitions
  class FocusAndSearchErrorsTest < ApplicationSystemTestCase
    def active_id = evaluate_script("document.activeElement.id")

    test "a page re-rendered in 422 by morphing puts the focus on the field in error, not on the clicked button" do
      member = create_team_member
      visit new_session_path
      fill_in "session[contact]", with: member.contact
      fill_in "session[pin]", with: "2468"
      click_on I18n.t("identity.sessions.new.submit")
      click_on "J'utilise un code de secours", wait: SIGN_IN_WAIT
      assert_selector "#second_factor_code:focus"

      page.execute_script("addEventListener('turbo:morph', () => document.body.dataset.morphed = 'yes', { once: true })")
      fill_in "Code de secours", with: "Zz9kP9wQ2m"
      click_on I18n.t("identity.second_factors.new.submit")

      assert_selector "body[data-morphed=yes]", visible: :all
      assert_selector "#second_factor_code_error", text: "Code incorrect."
      assert_selector "#second_factor_code[aria-invalid=true]:focus"
    end

    test "a modal re-rendered in 422 puts the focus on its first field in error, not on its first field" do
      school = create_school(name: "Lycée moderne de Cocody")
      sign_in_as create_team_member
      visit school_path(school.public_id)

      click_menu_action "#school_header", "Modifier"
      within "dialog#school-modal[open]" do
        assert_equal "school_name", active_id
        fill_in "school[national_code]", with: "12"
        click_on I18n.t("teams.schools.edit.submit")

        assert_selector "#school_national_code[aria-invalid=true]"
      end
      assert_selector "dialog#school-modal[open]"
      assert_equal "school_national_code", active_id
    end

    test "a search answered by an error page shows the error state in its frame, and Réessayer replays it" do
      classroom = create_classroom(name: "3e A")
      teacher = create_teacher(school: classroom.school, classrooms: [ classroom ])
      create_student(classroom:, first_name: "Awa", last_name: "Bamba")
      create_student(classroom:, first_name: "Koffi", last_name: "Yao")
      sign_in_as teacher
      visit classroom_path(classroom.public_id)
      assert_selector "turbo-frame#classroom_roster_list li", count: 2

      # The class disappears under the teacher: the search answers the 404 page, which has no such frame.
      public_id = classroom.public_id
      Orm::Classroom.where(id: classroom.id).update_all(public_id: "gone0000000000")
      fill_in I18n.t("classroom.classrooms.roster.search_label"), with: "Awa"

      within "turbo-frame#classroom_roster_list" do
        assert_selector "[role=alert]", text: I18n.t("components.error_state.title")
        again = find_link(I18n.t("components.error_state.retry"))
        assert_equal "_top", again["data-turbo-frame"]
        assert_equal "#{classroom_path(public_id)}?q=Awa", URI(again[:href]).request_uri
      end
      assert_no_text "Content missing"

      Orm::Classroom.where(id: classroom.id).update_all(public_id:)
      click_on I18n.t("components.error_state.retry")

      assert_current_path classroom_path(public_id, q: "Awa")
      assert_selector "turbo-frame#classroom_roster_list li", count: 1
      assert_no_selector "[role=alert]"
    end
  end
end
