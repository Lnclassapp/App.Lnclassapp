require "test_helper"

# hors-connexion, Lot A, CA-4 (ADR §4.2, menace P1) : la déconnexion demande au navigateur de vider son cache.
# Pas « storage » : il désinscrirait le programme d'arrière-plan et effacerait les files d'autres comptes.
class LogoutPurgeTest < ActionDispatch::IntegrationTest
  test "la réponse de la déconnexion porte Clear-Site-Data: \"cache\"" do
    sign_in_as create_student

    delete session_path

    assert_response :see_other
    assert_equal '"cache"', response.headers["Clear-Site-Data"]
  end

  test "la connexion et les autres réponses ne le portent pas" do
    student = create_student
    get new_session_path
    assert_nil response.headers["Clear-Site-Data"]

    sign_in_as student
    get student_home_path
    assert_nil response.headers["Clear-Site-Data"]
  end
end
