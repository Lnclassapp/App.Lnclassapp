require "application_system_test_case"

# CA-13, CA-14 (UDR-XXXX bloc « Suivi » et pipeline et relances): a member schedules a follow-up from the school page,
# finds it in « Mes relances » and marks it done; an admin reassigns the follow-up of an anonymized member, a field member
# who does not own the school cannot; on a 390 px phone the page does not scroll sideways.
class Teams::CrmFollowUpsTest < ApplicationSystemTestCase
  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Koné")
    @admin = create_team_member(team_role: "admin", first_name: "Yao", last_name: "Admin")
  end

  def tl(key, **) = I18n.t("teams.crm.follow_ups.#{key}", **)

  def open_school_follow_ups
    visit school_path(@school.public_id)
    assert_selector "#school_crm_follow_ups", text: tl("school.title")
  end

  test "CA-13: a member schedules a follow-up for tomorrow, finds it in Mes relances and marks it done" do
    sign_in_as @field
    open_school_follow_ups
    assert_text tl("school.empty")

    click_on tl("school.new")
    within("dialog[open]") do
      fill_in tl("form.due_on"), with: Date.current + 1
      fill_in tl("form.reason"), with: "Rappeler la direction"
      click_on tl("new.submit")
    end

    assert_no_selector "dialog[open]"
    within("#school_crm_follow_ups") do
      assert_text "Rappeler la direction"
      assert_text tl("follow_up.tomorrow")
    end

    visit teams_follow_ups_path
    within("table") { assert_text "Rappeler la direction" }
    within("#follow_up_row_#{Orm::CrmFollowUp.last.public_id}") { click_on tl("follow_up.complete") }

    assert_no_text "Rappeler la direction"
    assert_text tl("index.empty_mine")
    assert_equal "done", Orm::CrmFollowUp.last.status
  end

  test "CA-14: an admin reassigns the follow-up of an anonymized member from the Sans destinataire tab" do
    gone = create_team_member(team_role: "field", anonymized_at: Time.current)
    record = Orm::CrmFollowUp.create!(school: @school, assignee: gone, due_on: Date.current, reason: "Orpheline", created_by: @field)
    sign_in_as @admin

    visit teams_follow_ups_path(tab: "orphans")
    within("#follow_up_row_#{record.public_id}") { assert_text tl("follow_up.unavailable") }
    click_menu_action("#follow_up_row_#{record.public_id}", tl("follow_up.reassign"))
    within("dialog[open]") do
      select "Awa Koné", from: tl("assignee_form.assignee")
      click_on tl("edit.submit")
    end

    assert_no_selector "#follow_up_row_#{record.public_id}"
    assert_text tl("reassign.done", name: "Awa Koné")
    assert_equal @field.id, record.reload.assignee_id
  end

  test "CA-14: a field member who is not the owner of the school gets no « Réattribuer »" do
    Orm::CrmAccount.create!(school: @school, owner: @admin, stage_changed_at: Time.current)
    record = Orm::CrmFollowUp.create!(school: @school, assignee: @field, due_on: Date.current, reason: "À moi", created_by: @field)
    sign_in_as @field

    visit teams_follow_ups_path

    within("#follow_up_row_#{record.public_id}") do
      assert_text "À moi"
      assert_no_selector "button[aria-haspopup=menu]"
    end
  end

  test "on a 390 px phone the cards replace the table, without horizontal scroll" do
    record = Orm::CrmFollowUp.create!(school: @school, assignee: @field, due_on: Date.current - 1, reason: "Rappeler", created_by: @field)
    sign_in_as @field

    with_mobile_viewport do
      visit teams_follow_ups_path

      assert_no_selector "table"
      within("#follow_up_card_#{record.public_id}") do
        assert_text @school.name
        assert_text tl("follow_up.overdue")
      end
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
    end
  end
end
