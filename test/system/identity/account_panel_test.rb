require "application_system_test_case"

# CA-T6 (Lnclass Teacher) — UDR-0082 §3.1, UDR enseignant « écrans sans répétition » §3.4 (lot M, mvp-teacher-student). At 390 px,
# the teacher's header holds on one line without horizontal scroll: the avatar alone on the left, « Besoin d'aide ? » on the
# right (the switch is in the panel). Touching the avatar opens « Mon compte » full screen (CA-H1): « Mon profil »,
# « Modifier mon code secret », « Ajouter une matière » and « Ajouter un établissement » each with « N sur 3 », « Mode sombre »,
# « Se déconnecter »; the focus goes to the first entry; Escape closes it and gives the focus back to the avatar.
# The content, the counters at 3 on 3 and the schools of CA-H2 are covered by test/controllers/classroom/teacher_menus_controller_test.rb.
class Identity::AccountPanelTest < ApplicationSystemTestCase
  TRIGGER = "header a[aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def focused?(selector) = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")

  test "CA-T6, CA-H1: at 390 px, the teacher's avatar opens « Mon compte » full screen with its counters, Escape closes it" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré", school: create_school(name: "Lycée moderne 2", sigle: "LM2"), materials: [ maths ])

    # La barre de l'accueil enseignant porte son propre avatar (bandeau jaune, lien vers /teachers/menu) : ces deux tests lisent
    # la <dialog> de l'en-tête du shell, sur une page sans bandeau.
    with_mobile_viewport do
      visit profile_path

      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("header") do
        assert_selector TRIGGER.delete_prefix("header "), visible: true
        assert_no_selector "img[src*='logo']"
        assert_no_text "Awa Traoré"
        assert_link I18n.t("shared.help_sheet.trigger"), visible: true
        assert_no_selector "button[role=switch]", visible: true
      end

      find(TRIGGER).click
      panel = find("dialog#account_panel[open]", visible: true)
      size = page.evaluate_script("(r => [r.width, r.height, innerWidth, innerHeight])(document.getElementById('account_panel').getBoundingClientRect())")
      assert_in_delta size[2], size[0], 1
      assert_in_delta size[3], size[1], 1
      within(panel) do
        assert_selector "h2", text: tn("account_panel.title")
        assert_text "Awa Traoré"
        assert_text "Maths · LM2"
        assert_equal [ tn(:profile), tn("account_panel.entries.secret"),
                       "#{tn('account_panel.entries.add_material')} #{I18n.t('shared.navigation.account_panel.counter.under', used: 1, max: 3)}",
                       "#{tn('account_panel.entries.add_school')} #{I18n.t('shared.navigation.account_panel.counter.under', used: 1, max: 3)}" ],
                     all("nav a", minimum: 4).map { it.text.squish }
        assert_no_link "Inviter un collègue"
        assert_selector "button[role=switch]", visible: true
        assert_button tn(:sign_out)
      end
      assert focused?("dialog#account_panel a[href='#{profile_path}']"), "le focus ne va pas sur « Mon profil »"

      panel.send_keys(:escape)
      assert_no_selector "dialog#account_panel", visible: true
      assert focused?(TRIGGER), "le focus n'est pas revenu sur l'avatar"
    end
  end

  # UDR-0054, amendement « survol » ; chantier infobulle-badges-hors-ecran. Une fois glissé, le tiroir ne garde aucun
  # transform : sinon il devient le repère des descendants en position fixe (infobulles au survol) et les décale.
  test "once open, the account panel keeps no transform" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    # La barre de l'accueil enseignant porte son propre avatar (bandeau jaune, lien vers /teachers/menu) : ces deux tests lisent
    # la <dialog> de l'en-tête du shell, sur une page sans bandeau.
    with_mobile_viewport do
      visit profile_path
      find(TRIGGER).click
      find("dialog#account_panel[open]", visible: true)
      page.document.synchronize do
        finished = page.evaluate_script("document.getElementById('account_panel').getAnimations().every(a => a.playState === 'finished')")
        raise Capybara::ExpectationNotMet, "le panneau glisse encore" unless finished
      end

      assert_equal "none", page.evaluate_script("getComputedStyle(document.getElementById('account_panel')).transform")
    end
  end
end
