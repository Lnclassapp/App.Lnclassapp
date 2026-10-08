require "application_system_test_case"

# Finitions UX, Lot D2 (UDR-0054, amendments of UDR-0019, 0020, 0049, 0050): the team home is named, « Débloquer un
# compte » searches by itself once the number is complete, the DRENA of the dashboard applies on change, the indicators of
# the dashboard and of « Croissance » explain themselves, and the team invitation link copies in one click.
class FinitionsTeamAccountsTest < ApplicationSystemTestCase
  setup do
    @member = create_team_member(first_name: "Aya")
  end

  # FU-02 (team row)
  test "the team home is named « Accueil · Équipe · Lnclass »" do
    sign_in_as @member

    assert_current_path team_home_path
    assert_equal "Accueil · Équipe · Lnclass", page.title
  end

  # FU-10 (« Croissance », « Débloquer un compte »)
  test "« Croissance » and « Débloquer un compte » lead back to the home, first link of the main content" do
    sign_in_as @member

    [ teams_growth_path, teams_account_lookup_path ].each do |path|
      visit path

      back = first("main a")
      assert_equal "Accueil", back.text
      assert_equal team_home_path, URI(back[:href]).path
      assert_selector "main nav[aria-label=Retour] a", text: "Accueil"
    end
    assert_equal "Débloquer un compte · Équipe · Lnclass", page.title
  end

  # FU-50
  test "« Débloquer un compte » waits for the full number, then shows the account without a click" do
    create_student(classroom: create_classroom(name: "3e A"), contact: "0511223344", first_name: "Awa", last_name: "Koné")
    sign_in_as @member
    visit teams_account_lookup_path
    count_submissions("account-lookup-form")

    field = find_field("account_lookup_contact")
    assert_equal "account_lookup_contact", evaluate_script("document.activeElement.id")
    assert_no_selector "#account-lookup-form button[type=submit]"

    field.send_keys("05 11 22 33")
    sleep 0.6
    assert_equal 0, submissions
    assert_no_selector "#account-lookup-result"

    field.send_keys(" 44")
    within("turbo-frame#account_lookup #account-lookup-result") { assert_text "Awa Koné" }
    assert_equal 1, submissions
    assert_match(/contact=05\+11\+22\+33\+44/, current_url)
  end

  # FU-52
  test "the DRENA of the dashboard applies on change, without « Filtrer »" do
    abidjan = create_drena(name: "Abidjan 1")
    create_drena(name: "Bouaké")
    create_student(classroom: create_classroom(school: create_school(drena: abidjan)))
    sign_in_as @member
    visit team_dashboard_path

    assert_selector "form#team-dashboard-drena[role=search][aria-label='Filtrer par DRENA']"
    assert_no_selector "#team-dashboard-drena button[type=submit]"
    select "Abidjan 1", from: "DRENA"

    assert_selector "#team_dashboard_scope", text: "Abidjan 1"
    # UDR-0068 §3.6 : sous un filtre, « Par DRENA » laisse place aux établissements de la DRENA.
    assert_no_selector "#team_dashboard_drenas"
    assert_selector "#team_dashboard_schools tbody tr", count: 1
    assert_match(/drena=#{abidjan.public_id}/, current_url)
  end

  # FU-21 (dashboard), FU-23
  test "the dashboard indicators open their help, and at 390 px the page never scrolls sideways" do
    create_student(classroom: create_classroom(school: create_school(drena: create_drena(name: "Abidjan 1"))))
    sign_in_as @member
    visit team_dashboard_path

    labels = [ "Réussite moyenne", "Élèves actifs", "Établissements actifs", "Ouvert depuis l'app installée" ]
    labels.each { |label| assert_selector "details summary .sr-only", text: "Aide : #{label}", visible: :all }

    summary = find("#figure_completed_sessions summary")
    assert_equal "false", summary.evaluate_script("String(this.parentElement.open)")
    summary.click
    assert_selector "#figure_completed_sessions details[open]",
                    text: "Moyenne des scores des exercices terminés sur la période. — : aucun exercice terminé."

    with_mobile_viewport do
      execute_script("document.querySelectorAll('main details').forEach((details) => { details.open = true })")
      assert_selector "main details[open]", count: labels.size
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=,
                      evaluate_script("document.documentElement.clientWidth")
    end
  end

  # FU-21 (« Croissance »)
  test "the indicators of « Croissance » open their help" do
    sign_in_as @member
    visit teams_growth_path

    [ "k enseignant", "Conversion par partage", "Cycle viral médian", "Élèves arrivés par enseignant actif" ].each do |label|
      assert_selector "details summary .sr-only", text: "Aide : #{label}", visible: :all
    end
    find("#growth_k summary").click
    assert_selector "#growth_k details[open]", text: "Nombre moyen d'enseignants inscrits grâce à chaque nouvel enseignant"
    assert_equal "Croissance · Équipe · Lnclass", page.title
  end

  # FU-24
  test "the invitation link copies in one click, with the toast « Lien copié. »" do
    sign_in_as @member
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])

    within("#team_home_shortcuts") { click_link "Inviter un membre" }
    within("dialog#invitation-modal[open]") do
      assert_equal "invitation_contact", evaluate_script("document.activeElement.id")
      assert_equal "Inviter un membre de l'équipe · Équipe · Lnclass", page.title
      fill_in "invitation_contact", with: "01 00 00 00 09"
      choose "Contenu"
      click_on "Créer l'invitation"
    end

    link = find("dialog#invitation-created-modal[open] input#invitation-link").value
    within("dialog#invitation-created-modal[open]") do
      assert_selector "button[aria-label=\"Copier le lien d'invitation\"]", text: "Copier le lien"
      click_on "Copier le lien"
    end

    assert_toast "Lien copié."
    assert_equal link, page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  end

  private

  def count_submissions(form_id)
    execute_script(<<~JS, form_id)
      const id = arguments[0]
      window.submissions = 0
      document.addEventListener("turbo:submit-start", (event) => { if (event.target.id === id) window.submissions++ })
    JS
  end

  def submissions = evaluate_script("window.submissions")
end
