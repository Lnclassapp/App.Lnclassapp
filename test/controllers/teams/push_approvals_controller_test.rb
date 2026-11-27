require "test_helper"

# UDR XXXX (écran notifications de l'équipe) §3.4 ; ADR XXXX §4.4 : « Valider l'envoi » fige élève × objet, remplace la ligne du motif,
# ajoute une ligne à l'historique ; « Déjà validé », fermeture après 20 h et motifs non validables répondent sans rien écrire.
class Teams::PushApprovalsControllerTest < ActionDispatch::IntegrationTest
  NOW = Time.utc(2026, 11, 25, 10, 12)

  setup do
    @school = create_school(name: "Lycée Alpha")
    @classroom = create_classroom(school: @school)
    @ada = create_student(classroom: @classroom)
    @bob = create_student(classroom: @classroom)
    @awa = create_team_member(team_role: "content", first_name: "Awa", last_name: "Koné")
  end

  def candidates(*students, motive: "inactive")
    students.map do |student|
      Entities::Communication::PushCandidate.new(user_id: student.id, motive:, object_key: "#{motive}:7", url: "/eleve")
    end
  end

  def approve(motive = "inactive", list: candidates(@ada, @bob), at: NOW, format: :turbo_stream)
    stub_any_instance(Queries::Communication::PushCandidates, :for, ->(**) { list }) do
      travel_to(at) { post teams_push_approvals_path, params: { motive: }, as: format }
    end
  end

  test "an approval freezes the students and objects, replaces the motive line, replaces the history and toasts" do
    sign_in_as @awa
    assert_difference -> { Orm::Communication::PushApproval.count } => 1, -> { Orm::Communication::PushApprovalRecipient.count } => 2 do
      approve
    end

    assert_response :ok
    approval = Orm::Communication::PushApproval.sole
    assert_equal [ "inactive", Date.new(2026, 11, 25), @awa.id, 2 ], [ approval.motive, approval.on_date, approval.approved_by_id, approval.recipients_count ]
    assert_equal [ [ @ada.id, "inactive:7" ], [ @bob.id, "inactive:7" ] ], approval.recipients.order(:user_id).pluck(:user_id, :object_key)
    assert_select "turbo-stream[action=replace][target=push_plan_inactive]"
    assert_select "turbo-stream[action=replace][target=push_history] #push_history_list li", text: /Awa K\. a validé Élève inactif \(3, 7, 14 jours\) — 2 élèves/
    assert_match I18n.t("teams.push_approvals.create.approved", count: 2), response.body
    assert_select "turbo-stream[target=push_plan_inactive] span", text: "Validé"
  end

  test "a student who became concerned after the approval is not in the frozen list; the list is the one recomputed at approval" do
    sign_in_as @awa
    approve(list: candidates(@ada))

    assert_equal [ @ada.id ], Orm::Communication::PushApprovalRecipient.pluck(:user_id)
  end

  test "a second approval answers « Déjà validé par » with the real author, the recorded count, and writes nothing" do
    create_push_approval(motive: "inactive", on_date: NOW.to_date, approved_by: @awa, approved_at: NOW - 30.minutes, recipients: [ [ @ada.id, "inactive:7" ] ])
    sign_in_as create_team_member(team_role: "field")

    assert_no_difference -> { Orm::Communication::PushApproval.count } do
      approve
    end

    assert_response :ok
    assert_match I18n.t("teams.push_approvals.create.already_approved", name: "Awa K.", time: "09 h 42"), response.body
    assert_select "turbo-stream[action=prepend]", count: 0
    assert_select "turbo-stream[target=push_plan_inactive] p", text: /Awa K\..*1 élève/
  end

  test "after 20 h the approval is refused with the closing toast and nothing is written" do
    sign_in_as @awa
    assert_no_difference -> { Orm::Communication::PushApproval.count } do
      approve(at: Time.utc(2026, 11, 25, 20, 21))
    end

    assert_response :ok
    assert_match I18n.t("teams.push_approvals.create.closed"), response.body
    assert_select "turbo-stream[action=prepend]", count: 0
  end

  test "an automatic motive, nobody concerned: refused without writing; the announcement and an unknown motive are 404" do
    sign_in_as @awa
    create_push_motive_setting(motive: "quiz_prep", automatic: true)
    assert_no_difference -> { Orm::Communication::PushApproval.count } do
      approve("quiz_prep", list: candidates(@ada, motive: "quiz_prep"))
      assert_response :ok
      approve("unfinished", list: [])
      assert_response :ok
      approve("announcement")
      assert_response :not_found
      approve("nope")
      assert_response :not_found
    end
  end

  test "without JavaScript, the approval redirects to the page" do
    sign_in_as @awa
    approve(format: :html)

    assert_redirected_to teams_push_settings_path
    assert_equal 1, Orm::Communication::PushApproval.count
  end

  test "without JavaScript, a refused approval redirects with an alert, not a notice" do
    sign_in_as @awa
    approve(at: Time.utc(2026, 11, 25, 20, 21), format: :html)

    assert_redirected_to teams_push_settings_path
    assert_equal I18n.t("teams.push_approvals.create.closed"), flash[:alert]
  end

  test "an approved motive that was since made automatic still answers « déjà validé », without the line of a motive that left the plan" do
    sign_in_as @awa
    create_push_approval(motive: "quiz_prep", on_date: NOW.to_date, approved_by: @awa, approved_at: NOW - 1.hour, recipients: [ [ @ada.id, "quiz_prep:7" ] ])
    create_push_motive_setting(motive: "quiz_prep", automatic: true)
    approve("quiz_prep", list: candidates(@ada, motive: "quiz_prep"))

    assert_response :ok
    assert_match I18n.t("teams.push_plans.show.approved"), response.body
    assert_select "turbo-stream[action=replace]", count: 0
  end

  test "a teacher, a school admin or a student gets 403 and nothing is written; a visitor goes to the sign-in" do
    [ create_teacher, create_school_admin, create_student ].each do |someone|
      sign_in_as someone
      assert_no_difference -> { Orm::Communication::PushApproval.count } do
        approve

        assert_response :forbidden
      end
      sign_out
    end
    approve

    assert_redirected_to new_session_path
  end
end
