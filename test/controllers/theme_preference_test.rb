require "test_helper"

# UDR-0065, amendement du 2026-10-03 : le serveur rend le choix de l'interrupteur sur <html>, pour que la première image
# soit déjà dans le bon thème ; l'interrupteur est dans l'en-tête (grand écran) et dans le profil (téléphone, tablette).
class ThemePreferenceTest < ActionDispatch::IntegrationTest
  test "without a choice, the page carries no data-theme and lets the browser follow the phone" do
    get root_url

    assert_select "html:not([data-theme])"
    assert_select "meta[name=color-scheme][content='light dark']"
  end

  test "the choice of the switch, read in its cookie, is rendered on <html> and in the color-scheme meta" do
    cookies[:theme] = "dark"
    get root_url

    assert_select "html[data-theme=dark]"
    assert_select "meta[name=color-scheme][content=dark]"
  end

  test "a forged cookie is ignored" do
    cookies[:theme] = %("><script>)
    get root_url

    assert_select "html:not([data-theme])"
  end

  test "a signed-in user finds the switch next to the avatar on a wide screen, and in the profile below lg" do
    sign_in_as create_student(first_name: "Aya")
    cookies[:theme] = "dark"

    get profile_path

    assert_select "header div[data-controller=theme][hidden].max-lg\\:hidden" do
      assert_select "button[role=switch][aria-checked=true][aria-label='Mode sombre'][data-action='theme#toggle']"
    end
    assert_select "main div[data-controller=theme][hidden].lg\\:hidden #profile_theme[aria-labelledby=profile_theme_title]" do
      assert_select "h2#profile_theme_title", "Apparence"
      assert_select "button[role=switch][aria-checked=true]", text: /Mode sombre/
    end
  end

  # IT-05 : la page de protection des données dit vrai sur les cookies.
  test "the privacy page names the cookie that keeps the light or dark choice" do
    get privacy_path

    assert_response :success
    assert_match "celui qui retient, sur votre appareil, votre choix entre mode clair et mode sombre", response.body
  end
end
