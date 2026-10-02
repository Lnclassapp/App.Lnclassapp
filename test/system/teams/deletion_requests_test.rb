require "application_system_test_case"

# Lot R3 of fonctions-espace-eleve (ADR-0036, amendment (2)): on a 390 px phone, the team `admin` records the deletion
# request received 26 days ago from the account, sees the amber card on the team home, follows it to the list, opens the
# account and deletes it with the recorded date, without a page reload. The request is then processed.
class Teams::DeletionRequestsTest < ApplicationSystemTestCase
  setup do
    @student = create_student(classroom: create_classroom(name: "3ème 4"), contact: "0511223344", first_name: "Awa", last_name: "Koné")
    @received = Date.current - 26
    sign_in_as create_team_member(first_name: "Aya")
    assert_current_path team_home_path
  end

  def t(key, **) = I18n.t("teams.deletion_requests.#{key}", **)
  def date(value) = I18n.l(value, format: :due_short)

  def open_account
    visit teams_account_lookup_path
    fill_in "contact", with: "05 11 22 33 44"
    assert_selector "#account-lookup-result", text: "Awa Koné"
  end

  test "on a phone, the admin records a request, sees the card, and processes it from the account" do
    with_mobile_viewport do
      open_account

      assert_no_page_reload do
        within("#account-lookup-result") { click_on t("account_block.record") }
        within "dialog#deletion-request-modal[open]" do
          assert_text t("new.title", name: "Awa Koné")
          fill_in t("new.requested_on"), with: @received
          click_on t("new.submit")
        end
        assert_toast t("create.done", name: "Awa Koné")
        assert_no_selector "dialog#deletion-request-modal[open]"
        within("#account-deletion-request-pending") do
          assert_text t("account_block.received", date: date(@received))
          assert_selector ".bg-warning-soft", text: t("due.before", date: date(@received + 30))
        end
      end

      visit team_home_path
      within("#team_home_deletion_requests") do
        assert_text I18n.t("teams.homes.deletion_requests.pending", count: 1)
        assert_selector ".bg-warning-soft", text: t("due.before", date: date(@received + 30))
      end
      find("#team_home_deletion_requests").click

      assert_current_path teams_deletion_requests_path
      assert_single_primary_action
      assert_list_capped "#deletion_requests"
      click_on "Awa Koné"

      within("#account-lookup-result") do
        assert_text t("account_block.received", date: date(@received))
        click_on I18n.t("teams.account_lookups.result.delete_account")
      end
      within "dialog#account-deletion-modal[open]" do
        assert_equal @received.iso8601, find_field("account_deletion[requested_on]").value
        click_on I18n.t("teams.account_deletions.new.submit")
      end
      assert_toast I18n.t("teams.account_deletions.create.done", name: "Awa Koné")
      within("#account-lookup-result") { assert_text I18n.t("teams.account_deletions.create.title") }
    end

    request = Orm::AccountDeletionRequest.sole
    assert_equal [ "processed", @received ], [ request.status, request.requested_on ]
    assert_not_nil @student.reload.anonymized_at
    assert_equal [ "user.deletion_requested", "user.anonymized" ], Orm::AuditEvent.order(:id).pluck(:action).grep(/\Auser\./)

    visit team_home_path
    assert_selector "h1", text: "Aya"
    assert_no_selector "#team_home_deletion_requests"
  end

  test "the student takes the request back: the admin cancels it, and the card disappears" do
    Orm::AccountDeletionRequest.create!(user: @student, requested_on: Date.current - 31, recorded_by: create_team_member)

    visit team_home_path
    within("#team_home_deletion_requests") { assert_selector ".bg-warning-soft", text: t("due.late", date: date(Date.current - 1)) }

    open_account
    assert_no_page_reload do
      within("#account-deletion-request-pending") { click_on t("account_block.cancel") }
      assert_toast t("destroy.done", name: "Awa Koné")
      within("#account-lookup-result") { assert_link t("account_block.record") }
    end

    assert_equal [ "cancelled" ], Orm::AccountDeletionRequest.pluck(:status)
    visit team_home_path
    assert_selector "h1", text: "Aya"
    assert_no_selector "#team_home_deletion_requests"
  end
end
