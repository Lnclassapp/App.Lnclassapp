require "application_system_test_case"

# CA-E1 (mvp-teacher-student, lot E1) — UDR « écrans élève sans répétition » §3.1, §3.8. At 390 px, on a page other than the
# home (« Cours »), the avatar of the header opens « Mon compte » full screen: « Mon profil », « Modifier mon code secret »,
# « Mode sombre », « Se déconnecter », and nothing else. Escape closes it and gives the focus back to the avatar. On a computer
# the panel only has to open and close (the 400 px side panel is lot O2). The page /students/menu and the markup are covered
# by test/controllers/classroom/student_menus_controller_test.rb.
class Identity::StudentAvatarMenuTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  AVATAR = "header button#avatar-menu-button".freeze
  PANEL = "dialog#avatar-menu".freeze

  setup do
    @student = create_student(classroom: create_classroom(name: "Tle D 1", school: create_school(name: "Lycée moderne 2")),
                              first_name: "Awa", last_name: "Koné")
    sign_in_as @student
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)
  def focused?(selector) = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")
  def horizontal_scroll = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")

  def open_panel
    find(AVATAR).click
    assert_selector "#{PANEL}[open]", visible: true
  end

  test "CA-E1: at 390 px, the avatar opens « Mon compte » full screen with its four entries; Escape gives the focus back" do
    # On a computer, the panel only has to open and close without breaking the page.
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit courses_path
      open_panel
      within(PANEL) { assert_text "Awa Koné" }
      page.send_keys(:escape)
      assert_no_selector PANEL, visible: true
      assert focused?("#avatar-menu-button")
      assert_selector "aside nav a", text: tn(:home), visible: true
    end

    with_mobile_viewport do
      visit courses_path
      assert_no_selector PANEL, visible: true

      open_panel
      within(PANEL) do
        assert_selector "h2", text: tn("account_panel.title")
        assert_text "Awa Koné"
        assert_text "Tle D 1 · Lycée moderne 2"
        assert_equal [ tn(:profile), tn("account_panel.entries.secret") ], all("nav a", minimum: 2).map { it.text.squish }
        assert_selector "button[role=switch]", text: tn("account_panel.entries.dark_mode"), visible: true
        assert_button tn(:sign_out), visible: true
        [ tn(:home), tn(:courses), tn(:classroom), tn("avatar_menu.history"), I18n.t("shared.help_sheet.trigger") ].each do |gone|
          assert_no_link gone
        end
      end
      # Full screen: the panel takes the whole window, and the page does not scroll sideways.
      size = page.evaluate_script("(() => { const r = document.querySelector('#{PANEL}').getBoundingClientRect(); " \
                                  "return [r.width, r.height, innerWidth, innerHeight] })()")
      assert_in_delta size[2], size[0], 1
      assert_in_delta size[3], size[1], 1
      assert_equal 0, horizontal_scroll
      assert focused?("#{PANEL} a[href='#{profile_path}']"), "le focus ne va pas sur « Mon profil »"

      page.send_keys(:escape)
      assert_no_selector PANEL, visible: true
      assert focused?("#avatar-menu-button"), "le focus n'est pas revenu sur l'avatar"

      # The close cross closes it too; the dark mode switch turns the page dark; « Se déconnecter » signs out.
      open_panel
      within(PANEL) { find("button[role=switch]").click }
      assert_selector "html[data-theme=dark]"
      within(PANEL) { find("button[aria-label='#{I18n.t('components.modal.close')}']").click }
      assert_no_selector PANEL, visible: true
      open_panel
      within(PANEL) { click_on tn(:sign_out) }
      assert_current_path root_path
    end
  end
end
