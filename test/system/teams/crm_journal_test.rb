require "application_system_test_case"

# CA-11 (ADR-XXXX contexte crm, UDR-XXXX bloc « Suivi ») : un membre `field` note un appel positif depuis la fiche d'un
# établissement ; l'échange passe en tête du journal et la relance est créée ; au-delà de 20 échanges, un lien charge la suite.
class Teams::CrmJournalTest < ApplicationSystemTestCase
  setup do
    @school = create_school
    @field = create_team_member(team_role: "field", first_name: "Awa", last_name: "Koné")
    sign_in_as @field
    assert_current_path team_home_path
  end

  test "CA-11: a positive call with a note and a follow-up in 3 days leads the journal; older ones load on demand" do
    25.times do |i|
      Orm::CrmInteraction.create!(school: Orm::School.find(@school.id), author: @field, kind: "visit", outcome: "neutral",
                                  occurred_at: Time.zone.now - (i + 2).days, note: "ancien #{i}")
    end
    visit school_path(@school.public_id)

    within("turbo-frame#school_crm_journal") do
      assert_selector "ol > li", count: 20
      click_on "Noter un échange"
    end
    within("dialog#interaction-modal[open]") do
      choose "Appel"
      choose "Positif"
      fill_in "Note", with: "Directrice intéressée par la démo"
      fill_in "Prochaine étape", with: "Envoyer la plaquette"
      check "Créer une relance"
      click_on "Noter l'échange"
    end

    assert_toast "Échange noté"
    within("turbo-frame#school_crm_journal") do
      assert_selector "ol > li:first-child", text: "Directrice intéressée par la démo"
      assert_selector "ol > li:first-child", text: "Awa Koné"
      assert_selector "ol > li", count: 20
      click_on "Voir les échanges plus anciens"
      assert_selector "li", text: "ancien 24"
      assert_no_link "Voir les échanges plus anciens"
    end
    assert_equal [ Date.current + 3, "Envoyer la plaquette" ], Orm::CrmFollowUp.last.then { [ it.due_on, it.reason ] }
  end

  test "a follow-up dated in the past keeps the modal open with the error and writes nothing" do
    visit school_path(@school.public_id)
    click_on "Noter un échange"
    within("dialog#interaction-modal[open]") do
      choose "Appel"
      choose "Neutre"
      check "Créer une relance"
      fill_in "Date de la relance", with: Date.current - 1
      click_on "Noter l'échange"
    end
    # The date goes in as a Date, not as « dd/mm/yyyy »: Chrome reads that string as mm/dd/yyyy, so on days 1 to 13 yesterday
    # became a day of December, the follow-up was valid and the modal closed (chantier tests-instables-crm-journal). The 422
    # answer replaces the whole dialog inside the « modal » frame: the error is looked up from the page, not from the old one.
    assert_selector "dialog#interaction-modal[open] [id$=_error]"
    assert_equal 0, Orm::CrmInteraction.count
  end
end
