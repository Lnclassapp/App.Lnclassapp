require "application_system_test_case"

# Lot R of fonctions-espace-eleve (ADR-0036 §4): a student asked the support to delete the account; a team member looks
# up the number, opens « Supprimer le compte », gives the date of the request and confirms, without a page reload. The
# account is anonymized and its results stay.
class Teams::AccountDeletionTest < ApplicationSystemTestCase
  unless Object.const_defined?("Teams::HomesController")
    Teams.const_set(:HomesController, Class.new(Teams::BaseController) {
      def show = render(html: "home", layout: true, formats: :html)
    })
  end

  setup do
    @student = create_student(classroom: create_classroom(name: "3ème 4"), contact: "0511223344", first_name: "Awa", last_name: "Koné")
    @session = create_exercise_session(student: @student, status: "completed")
    sign_in_as create_team_member
    assert_current_path team_home_path
  end

  def t(key, **) = I18n.t("teams.account_deletions.#{key}", **)

  test "the team deletes a student account on request, with the date of the request, in the modal" do
    visit teams_account_lookup_path

    assert_no_page_reload do
      fill_in "contact", with: "05 11 22 33 44"
      within("#account-lookup-result") { click_on I18n.t("teams.account_lookups.result.delete_account") }

      within "dialog#account-deletion-modal[open]" do
        assert_text t("new.title", name: "Awa Koné")
        click_on t("new.submit")
        assert_selector "#account_deletion_requested_on:invalid"
        fill_in I18n.t("activemodel.attributes.dtos/identity/deletion_request_input.requested_on"), with: Date.current - 5
        click_on t("new.submit")
      end

      assert_toast t("create.done", name: "Awa Koné")
      assert_no_selector "dialog#account-deletion-modal[open]"
      within("#account-lookup-result") { assert_text t("create.title") }
    end
    @student.reload
    assert_equal [ "Compte", "supprimé", nil ], [ @student.first_name, @student.last_name, @student.contact ]
    assert_equal({ "requested_on" => (Date.current - 5).iso8601 }, Orm::AuditEvent.find_by!(action: "user.anonymized").metadata)
    assert Orm::ExerciseSession.exists?(@session.id)
  end
end
