require "test_helper"

# hors-connexion, Lot A, CA-4 (ADR §4.2, menace P1). La déconnexion ne porte plus Clear-Site-Data : sur HTTPS, Chrome retenait
# la redirection 303 le temps de vider le cache, et la déconnexion ne ramenait pas à l'accueil. Le filet reste l'en-tête forget.
class LogoutPurgeTest < ActionDispatch::IntegrationTest
  test "la déconnexion redirige vers l'accueil sans Clear-Site-Data" do
    sign_in_as create_student

    delete session_path

    assert_redirected_to root_path
    assert_response :see_other
    assert_nil response.headers["Clear-Site-Data"]
  end

  test "la connexion et les autres réponses ne le portent pas" do
    student = create_student
    get new_session_path
    assert_nil response.headers["Clear-Site-Data"]

    sign_in_as student
    get student_home_path
    assert_nil response.headers["Clear-Site-Data"]
  end

  # Filet serveur (ADR §4.2, menace P1) : l'en-tête forget fait purger le programme.
  test "une page HTML vue sans être connecté porte Lnclass-Offline: forget" do
    get new_session_path

    assert_equal "forget", response.headers["Lnclass-Offline"]
  end

  test "une page de compte connecté porte keep, jamais forget" do
    sign_in_as create_student
    get student_home_path

    assert_not_equal "forget", response.headers["Lnclass-Offline"]
  end
end
