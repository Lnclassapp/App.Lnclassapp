require "test_helper"

# UDR-0187 §3.1 à §3.5 et amendement du 2026-11-27 (II) : la page est servie à toute l'équipe, jamais à un autre rôle ;
# elle dit quand l'envoi est coupé, montre les sept motifs et l'historique des 14 derniers jours, sans nom d'élève.
class Teams::PushSettingsControllerTest < ActionDispatch::IntegrationTest
  KEYS = %w[PUSH_DELIVERY_ENABLED VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY VAPID_SUBJECT].freeze

  setup do
    @admin = create_team_member
    @saved = KEYS.index_with { ENV[it] }
    ENV["PUSH_DELIVERY_ENABLED"] = "true"
    ENV["VAPID_PUBLIC_KEY"] = "BPublicKeyForTests"
    ENV["VAPID_PRIVATE_KEY"] = "PrivateKeyForTests"
    ENV["VAPID_SUBJECT"] = "mailto:equipe@example.test"
  end

  teardown { @saved.each { |key, value| ENV[key] = value } }

  def tl(key, **) = I18n.t("teams.push_settings.#{key}", **)

  test "a teacher, a student and a school admin receive 403; a visitor goes to the sign-in" do
    [ create_teacher, create_student, create_user(role: "school_admin") ].each do |user|
      sign_in_as user
      get teams_push_settings_path

      assert_response :forbidden
      sign_out
    end

    get teams_push_settings_path

    assert_redirected_to new_session_path
  end

  test "every team sub-role reads the page, marked current in the navigation" do
    %w[admin content field].each do |team_role|
      sign_in_as create_team_member(team_role:)
      get teams_push_settings_path

      assert_response :success
      assert_select "h1", tl("show.title")
      assert_select "[aria-current=page]", text: I18n.t("shared.navigation.push_settings")
      sign_out
    end
  end

  test "the seven motives are listed in priority order, each with its switch, its example text and its hint (event or reminder)" do
    sign_in_as @admin
    get teams_push_settings_path

    ids = css_select("#push_settings_modes li[id^=push_motive_]").pluck("id")
    assert_equal Entities::Communication::PushMotive::PRIORITY.map { "push_motive_#{it}" }, ids
    Entities::Communication::PushMotive::PRIORITY.each do |motive|
      assert_select "#push_motive_#{motive} input[type=checkbox][role=switch]:not([disabled])"
    end
    Entities::Communication::PushMotive::EVENTS.each { assert_select "#push_motive_#{it}_state", text: /#{Regexp.escape(tl("modes.hints.event"))}/ }
    Entities::Communication::PushMotive::REMINDERS.each { assert_select "#push_motive_#{it}_state", text: /#{Regexp.escape(tl("modes.hints.reminder"))}/ }
    assert_select "#push_motive_assignment_new", text: /Exercice assigné/
    assert_select "#push_motive_assignment_new", text: /t'a donné 3 exercices/
  end

  test "a checked motive says who set it and when; an unchecked one says nothing is sent" do
    author = create_team_member(first_name: "Awa", last_name: "Koné")
    create_push_motive_setting(motive: "assignment_due", automatic: true, updated_by: author, updated_at: Time.zone.local(2026, 11, 20, 9))
    sign_in_as @admin
    get teams_push_settings_path

    assert_select "#push_motive_assignment_due_state", text: /Automatique depuis le 20 nov\., par Awa K\./
    assert_select "#push_motive_assignment_due input[type=checkbox][checked]"
    assert_select "#push_motive_quiz_prep_state", text: /#{Regexp.escape(tl("modes.state_off"))}/
    assert_select "#push_motive_quiz_prep input[type=checkbox][checked]", 0
  end

  test "a content or field member sees the switches disabled, with the reason" do
    %w[content field].each do |team_role|
      sign_in_as create_team_member(team_role:)
      get teams_push_settings_path

      assert_select "#push_motive_quiz_prep input[type=checkbox][disabled][aria-disabled=true]"
      assert_select "#push_motive_quiz_prep_state", text: /#{Regexp.escape(tl("modes.admin_only"))}/
      sign_out
    end
  end

  test "the banner shows only the first case that applies, and never a key value" do
    sign_in_as @admin
    get teams_push_settings_path
    assert_select "#push_settings_switch_off, #push_settings_not_configured", 0

    ENV["VAPID_PRIVATE_KEY"] = nil
    get teams_push_settings_path
    assert_select "#push_settings_not_configured[role=status]", text: tl("banner.not_configured")
    assert_select "#push_settings_switch_off", 0

    ENV["PUSH_DELIVERY_ENABLED"] = "false"
    get teams_push_settings_path
    assert_select "#push_settings_switch_off[role=status]", text: tl("banner.switch_off")
    assert_select "#push_settings_not_configured", 0
    assert_no_match(/BPublicKeyForTests|mailto:equipe/, response.body)
  end

  test "there is no daily plan any more; the history keeps past approvals, is the last 14 days, newest first, with no student name" do
    awa = create_team_member(first_name: "Awa", last_name: "Koné")
    student = create_student(first_name: "Eleve", last_name: "Secret")
    create_push_approval(motive: "inactive", approved_by: awa, approved_at: 2.hours.ago, recipients: [ [ student.id, "inactive:3" ] ])
    Orm::Communication::PushMotiveSettingChange.create!(motive: "assignment_due", automatic: true, changed_by: awa, changed_at: 1.day.ago)
    Orm::Communication::PushMotiveSettingChange.create!(motive: "quiz_prep", automatic: false, changed_by: awa, changed_at: 20.days.ago)
    sign_in_as @admin
    get teams_push_settings_path

    assert_select "turbo-frame#push_plan", 0
    assert_no_match(/Valider l'envoi/, response.body)
    entries = css_select("#push_history_list li").map { it.text.squish }
    assert_equal 2, entries.size
    assert_match(/Awa K\. a validé Élève inactif \(3, 7, 14 jours\) — 1 élève/, entries.first)
    assert_match(/Awa K\. a rendu Devoir à rendre demain automatique/, entries.last)
    assert_no_match(/Secret|Eleve/, response.body)
  end

  test "the history shows the time of each entry, in Abidjan time" do
    awa = create_team_member(first_name: "Awa", last_name: "Koné")
    at = Time.utc(2026, 11, 25, 9, 12)
    Orm::Communication::PushMotiveSettingChange.create!(motive: "assignment_due", automatic: true, changed_by: awa, changed_at: at)
    sign_in_as @admin
    travel_to(Time.utc(2026, 11, 25, 12)) { get teams_push_settings_path }

    assert_select "#push_history_list li", text: /25 nov\. 9 h 12 · Awa K\./
  end

  # Amendement II : le plan du jour et la validation sont retirés ; leurs anciennes adresses n'existent plus.
  test "the old plan and approval addresses are gone" do
    sign_in_as @admin

    get "/teams/notifications/plan"
    assert_response :not_found
    post "/teams/notifications/approvals", params: { motive: "inactive" }
    assert_response :not_found
  end

  test "an empty history shows its empty state" do
    sign_in_as @admin
    get teams_push_settings_path

    assert_select "#push_history", text: /#{Regexp.escape(tl("history.empty.title"))}/
  end
end
