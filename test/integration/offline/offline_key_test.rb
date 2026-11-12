require "test_helper"

# hors-connexion, Lot 0, CA-2 (ADR §4.2, menace P2) : chaque page d'un compte connecté porte une clé d'appareil opaque.
class OfflineKeyTest < ActionDispatch::IntegrationTest
  KEY = /<meta name="lnclass-offline-key" content="([0-9a-f]{16})"/

  def key_of_page(path = "/")
    get path
    response.body[KEY, 1]
  end

  test "la clé est stable pour un compte, différente entre deux comptes, et ne contient pas l'identifiant" do
    first = create_student
    second = create_student

    sign_in_as(first)
    key = key_of_page(student_home_path)
    assert_match(/\A[0-9a-f]{16}\z/, key)
    assert_equal key, key_of_page(student_home_path)
    assert_not_includes key, first.id.to_s.rjust(16, "0")
    sign_out

    sign_in_as(second)
    assert_not_equal key, key_of_page(student_home_path)
  end

  test "une page sans connexion ne porte pas la clé" do
    get new_session_path

    assert_response :success
    assert_no_match(/lnclass-offline-key/, response.body)
  end

  test "la page connectée porte le contrôleur d'arrière-plan et le bandeau, caché" do
    sign_in_as(create_student)
    get student_home_path

    assert_select "div[hidden][data-controller='offline-session offline-sync']"
    assert_select "div#offline_status[hidden][role='status'][data-controller='offline-status']"
  end
end
