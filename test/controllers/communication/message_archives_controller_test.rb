require "test_helper"

# AN-15, AN-19, UDR-0071 §3.7: its author archives an announcement after a confirmation, and comes back to « Mes
# annonces » with a toast; anyone else, the team and the direction included, receives 404 and nothing changes.
class Communication::MessageArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @lauriers = create_school(name: "Collège Les Lauriers")
    @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
    @message = create_message(author: @kamate, title: "Devoirs communs", school: @lauriers)
  end

  def archive(message = @message) = post announcement_archive_path(message.public_id)

  test "AN-19 — its author archives « Devoirs communs »: back to « Mes annonces », with a toast" do
    sign_in_as @kamate

    archive

    assert_redirected_to my_announcements_path
    assert_equal "Annonce archivée.", flash[:notice]
    assert_equal "archived", @message.reload.status
    follow_redirect!
    assert_select "#toasts", text: /Annonce archivée\./
    assert_select "#my_announcement_#{@message.public_id} p.text-mute", text: /Archivée le/
  end

  test "AN-19 — archived, it cannot be archived again: back to « Mes annonces », with an alert" do
    @message.update!(status: "archived")
    sign_in_as @kamate

    archive

    assert_redirected_to my_announcements_path
    assert_equal "Cette annonce est déjà archivée ou retirée.", flash[:alert]
  end

  test "AN-15 — another direction, the team and a teacher receive 404; the announcement is unchanged" do
    [ create_school_admin(school: @lauriers, last_name: "Diallo"), create_team_member, create_teacher(school: @lauriers) ].each do |other|
      sign_in_as other
      archive
      assert_response :not_found
      sign_out
    end
    assert_equal "published", @message.reload.status
  end

  test "a student receives 403 and a visitor is sent to sign in" do
    sign_in_as create_student
    archive
    assert_response :forbidden
    sign_out

    archive
    assert_redirected_to new_session_path
    assert_equal "published", @message.reload.status
  end
end
