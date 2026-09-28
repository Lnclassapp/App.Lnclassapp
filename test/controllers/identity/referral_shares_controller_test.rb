require "test_helper"

# CP-04, CP-07 (ADR-0049, ADR-0063): a click on « Partager » is recorded by the server, on the session, and answers 204
# without setting any cookie; only a teacher of an active school may record one.
class Identity::ReferralSharesControllerTest < ActionDispatch::IntegrationTest
  test "CP-04: a teacher of an active school records a share of each channel, and no cookie beyond the session is set" do
    teacher = create_teacher
    sign_in_as teacher

    %w[whatsapp sms copy native].each do |channel|
      post teacher_referral_shares_path, params: { channel: }

      assert_response :no_content
      assert_equal [ Rails.application.config.session_options[:key] ], response.headers["Set-Cookie"].to_s.scan(/^([^=;\s]+)=/).flatten,
                   "ni cookie ni traceur en plus de la session (#{channel})"
    end
    assert_equal %w[whatsapp sms copy native], Orm::ReferralShare.where(user: teacher).order(:id).pluck(:channel)
  end

  test "an unknown channel is refused in 422, nothing is recorded" do
    sign_in_as create_teacher

    post teacher_referral_shares_path, params: { channel: "email" }

    assert_response :unprocessable_entity
    assert_equal 0, Orm::ReferralShare.count
  end

  test "CP-07: a teacher of a draft school, a student and the team are refused in 403" do
    team = create_team_member
    [ create_teacher(school: create_school(status: "draft")), create_student(classroom: create_classroom), team ].each do |user|
      sign_in_as user
      post teacher_referral_shares_path, params: { channel: "whatsapp" }

      assert_response :forbidden, user.role
      sign_out
    end
    assert_equal 0, Orm::ReferralShare.count
  end

  test "a visitor is sent to the sign-in page" do
    post teacher_referral_shares_path, params: { channel: "whatsapp" }

    assert_redirected_to new_session_path
  end
end
