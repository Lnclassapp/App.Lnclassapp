require "application_system_test_case"

# CA-1, CA-2, CA-3 (accueil-eleve) — UDR-0084 §3.1, §3.2, §3.3, §3.10. On a 390 px phone, the student's header shows the
# logo, the switch and the avatar alone; no bottom bar. The avatar opens a menu anchored under it, on the right: identity,
# Accueil / Cours / Ma classe (the page on screen highlighted), then « Mon profil », « Mon historique », « Ajouter ma
# photo », « Besoin d'aide ? » and « Se déconnecter », in that order. Arrow keys move, Escape and a click outside close,
# the focus goes back to the avatar. On a 1 280 px computer, « Besoin d'aide ? » is in the header, the left menu is
# visible, and the menu keeps only what the screen does not already show.
class Identity::StudentAvatarMenuTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  AVATAR = "header button#avatar-menu-button".freeze

  setup do
    @student = create_student(classroom: create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2")),
                              first_name: "Awa", last_name: "Koné")
    sign_in_as @student
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)
  def help = I18n.t("shared.help_sheet.trigger")
  def horizontal_scroll = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  def focused?(selector) = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
  def visible_items = all("#avatar-menu [role=menuitem]", visible: true).map { it.text.squish }

  def open_menu
    find(AVATAR).click
    assert_selector "#avatar-menu[role=menu]", visible: true
    assert_selector "#{AVATAR}[aria-expanded=true]"
  end

  test "CA-1, CA-3: at 390 px, the logo and the avatar alone, no switch, no bottom bar; the menu in order" do
    with_mobile_viewport do
      visit courses_path

      assert_equal 0, horizontal_scroll
      within("header") do
        assert_selector "a[href='#{student_home_path}'] img[src*='logo']", visible: true
        assert_no_selector "button[role=switch]"
        assert_selector "button#avatar-menu-button[aria-label='#{tn('avatar_menu.open', name: 'Awa Koné')}']", visible: true
        assert_no_text "Awa Koné"
        assert_no_link help
      end
      assert_no_selector "nav.bottom-0"
      assert_no_selector "aside", visible: true

      open_menu
      within("#avatar-menu") do
        assert_text "Awa Koné"
        assert_text "Tle D 1 · Lycée moderne 2"
        assert_selector "a[role=menuitem][aria-current=page].bg-brand-soft[href='#{courses_path}']", text: tn(:courses)
      end
      assert_equal [ tn(:home), tn(:courses), tn(:classroom), tn(:profile), tn("avatar_menu.history"),
                     tn("avatar_menu.add_photo"), help, tn(:sign_out) ], visible_items
      menu = page.evaluate_script(<<~JS)
        (() => { const m = document.getElementById("avatar-menu").getBoundingClientRect(),
                       a = document.getElementById("avatar-menu-button").getBoundingClientRect();
                 return { width: m.width, right: m.right, top: m.top, avatarRight: a.right, avatarBottom: a.bottom } })()
      JS
      assert_in_delta 288, menu["width"], 1, "le menu ne fait pas 288 px"
      assert_in_delta menu["avatarRight"], menu["right"], 1, "le menu n'est pas ancré à droite, sous l'avatar"
      assert_operator menu["top"], :>=, menu["avatarBottom"]
      assert_equal 0, horizontal_scroll

      # UDR-0084 §3.10: the keyboard — arrows move and loop, Escape closes and gives the focus back to the avatar.
      assert focused?("#avatar-menu a[href='#{student_home_path}']"), "le focus n'est pas sur la première entrée"
      page.send_keys(:down)
      assert focused?("#avatar-menu a[href='#{courses_path}']"), "la flèche bas ne passe pas à « Cours »"
      # Focused, the current page keeps its bg-brand-soft highlight, not the grey focus background of the other entries.
      brand_soft, focused_bg = page.evaluate_script(<<~JS)
        (() => { const probe = document.createElement("span"); probe.className = "bg-brand-soft"; document.body.append(probe);
                 const want = getComputedStyle(probe).backgroundColor; probe.remove();
                 return [want, getComputedStyle(document.activeElement).backgroundColor] })()
      JS
      assert_equal brand_soft, focused_bg, "la page en cours perd sa surbrillance au focus"
      page.send_keys(:up, :up)
      assert focused?("#avatar-menu form button"), "la flèche haut ne boucle pas sur « Se déconnecter »"
      page.send_keys(:escape)
      assert_no_selector "#avatar-menu", visible: true
      assert_selector "#{AVATAR}[aria-expanded=false]"
      assert focused?("#avatar-menu-button"), "le focus n'est pas revenu sur l'avatar"

      # A real click in the left gutter of the page, outside the menu and on no link, closes it.
      open_menu
      page.driver.browser.action.move_to_location(4, 400).click.perform
      assert_no_selector "#avatar-menu", visible: true

      # Under 700 px, « Besoin d'aide ? » of the menu opens the help sheet.
      open_menu
      within("#avatar-menu") { click_on help }
      assert_selector "dialog#help-sheet[open]", visible: true
      assert_no_selector "#avatar-menu", visible: true
      find("dialog#help-sheet[open]").send_keys(:escape)
      assert_no_selector "dialog#help-sheet", visible: true

      # A destination opens its page, then highlighted in the menu.
      open_menu
      within("#avatar-menu") { click_link tn(:courses) }
      assert_current_path courses_path
      open_menu
      assert_selector "#avatar-menu a[aria-current=page].bg-brand-soft[href='#{courses_path}']", text: tn(:courses)
    end
  end

  test "CA-2: at 1 280 px, « Besoin d'aide ? » is in the header, the left menu is visible, the menu has neither; sign-out" do
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit student_home_path

      within("header") do
        assert_link help, visible: true
        assert_no_text "Awa Koné"
      end
      assert_selector "aside nav a", text: tn(:home), visible: true
      assert_no_selector "nav.bottom-0"

      open_menu
      assert_equal [ tn(:profile), tn("avatar_menu.history"), tn("avatar_menu.add_photo"), tn(:sign_out) ], visible_items
      assert focused?("#avatar-menu a[href='#{profile_path}']"), "le focus ne va pas sur la première entrée visible"
      within("#avatar-menu") { assert_text "Awa Koné" }
      page.send_keys(:escape)

      within("header") { click_link help }
      assert_selector "dialog#help-sheet[open]", visible: true
      find("dialog#help-sheet[open]").send_keys(:escape)
      assert_no_selector "dialog#help-sheet", visible: true

      open_menu
      within("#avatar-menu") { click_on tn(:sign_out) }
      assert_current_path root_path
      visit student_home_path
      assert_current_path new_session_path
    end
  end
end
