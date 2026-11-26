require "test_helper"

# UDR XXXX §3.3 : un admin coche « Automatique » sans recharger la page ; un autre rôle, un motif forgé hors AUTOMATABLE
# ou un visiteur ne change rien. Réponse en Turbo Stream (ligne et plan remplacés, toast), redirection sans JavaScript.
class Teams::PushMotiveSettingsControllerTest < ActionDispatch::IntegrationTest
  setup { @admin = create_team_member }

  def turbo(motive, automatic) = patch(teams_push_motive_setting_path(motive), params: { automatic: }, as: :turbo_stream)

  test "an admin checks « devoir à rendre » : stored with the author, history written, line and plan replaced, toast" do
    sign_in_as @admin

    turbo("assignment_due", "1")

    assert_response :success
    row = Orm::Communication::PushMotiveSetting.find_by!(motive: "assignment_due")
    assert row.automatic
    assert_equal @admin.id, row.updated_by_id
    assert_equal [ [ "assignment_due", true, @admin.id ] ],
                 Orm::Communication::PushMotiveSettingChange.pluck(:motive, :automatic, :changed_by_id)
    assert_select "turbo-stream[action=replace][target=push_motive_assignment_due]"
    assert_select "turbo-stream[action=replace][target=push_plan]"
    assert_select "turbo-stream[action=replace][target=push_history] #push_history_list li", text: /a rendu Devoir à rendre demain automatique/
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("teams.push_motive_settings.update.saved"))}/
    assert_select "turbo-stream[target=push_motive_assignment_due] input[type=checkbox][checked]"
  end

  test "unchecking writes automatic false and one more history line" do
    create_push_motive_setting(motive: "quiz_prep", automatic: true)
    sign_in_as @admin

    turbo("quiz_prep", "0")

    assert_response :success
    assert_not Orm::Communication::PushMotiveSetting.find_by!(motive: "quiz_prep").automatic
    assert_equal 1, Orm::Communication::PushMotiveSettingChange.where(motive: "quiz_prep", automatic: false).count
  end

  test "without JavaScript the answer is a redirect to the page" do
    sign_in_as @admin

    patch teams_push_motive_setting_path("quiz_prep"), params: { automatic: "1" }

    assert_redirected_to teams_push_settings_path
    assert Orm::Communication::PushMotiveSetting.find_by!(motive: "quiz_prep").automatic
  end

  test "a content or field member is refused with 403 and an error toast, nothing is written" do
    %w[content field].each do |team_role|
      sign_in_as create_team_member(team_role:)

      turbo("assignment_due", "1")

      assert_response :forbidden
      sign_out
    end
    assert_equal 0, Orm::Communication::PushMotiveSetting.count
    assert_equal 0, Orm::Communication::PushMotiveSettingChange.count
  end

  test "a forged reminder motive is refused, nothing is written" do
    sign_in_as @admin

    %w[inactive unfinished result announcement nope].each do |motive|
      turbo(motive, "1")

      assert_response :unprocessable_entity, motive
      assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("teams.push_motive_settings.update.failed"))}/
    end
    assert_equal 0, Orm::Communication::PushMotiveSetting.count
  end

  test "without JavaScript a refusal is the 403 page for a content member and a redirect with an alert for a forged motive" do
    sign_in_as create_team_member(team_role: "content")
    patch teams_push_motive_setting_path("assignment_due"), params: { automatic: "1" }
    assert_response :forbidden
    sign_out

    sign_in_as @admin
    patch teams_push_motive_setting_path("nope"), params: { automatic: "1" }
    assert_redirected_to teams_push_settings_path
    assert_equal I18n.t("teams.push_motive_settings.update.failed"), flash[:alert]
    assert_equal 0, Orm::Communication::PushMotiveSetting.count
  end

  test "a teacher, a student and a visitor cannot change a setting" do
    [ create_teacher, create_student ].each do |user|
      sign_in_as user
      turbo("assignment_due", "1")

      assert_response :forbidden
      sign_out
    end
    turbo("assignment_due", "1")

    assert_response :redirect
    assert_equal 0, Orm::Communication::PushMotiveSetting.count
  end
end
