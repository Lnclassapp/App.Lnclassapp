require "test_helper"

# CA-17 (suivi-classe-lecon, Lot F) : l'envoi d'une image de question par l'équipe n'a plus d'appelant ; l'adresse est retirée.
class Teams::QuestionImagesGoneTest < ActionDispatch::IntegrationTest
  test "un membre de l'équipe connecté qui envoie une image de question sur l'ancien chemin reçoit 404" do
    sign_in_as create_team_member(team_role: "content")

    post "/teams/question-images", headers: { "Accept" => "application/json" }

    assert_response :not_found
  end
end
