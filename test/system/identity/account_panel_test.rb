require "application_system_test_case"

# CA-T6 (Lnclass Teacher) — UDR-0082 §3.1, UDR enseignant « écrans sans répétition » §3.4 (lot M, mvp-teacher-student), amended by
# UDR accueil-enseignant-actions §3.4: the teacher has no top bar outside the home, and none under lg. At 390 px the avatar of
# the home band leads to « Mon compte » (CA-H1): « Mon profil »,
# « Modifier mon code secret », « Ajouter une matière » and « Ajouter un établissement » each with « N sur 3 », « Mode sombre »,
# « Se déconnecter », then its way back to the home.
# The content, the counters at 3 on 3 and the schools of CA-H2 are covered by test/controllers/classroom/teacher_menus_controller_test.rb.
class Identity::AccountPanelTest < ApplicationSystemTestCase
  TRIGGER = "header a[aria-controls=account_panel]".freeze

  def tn(key) = I18n.t("shared.navigation.#{key}")
  def focused?(selector) = page.evaluate_script("document.activeElement.matches(#{selector.to_json})")

  # UDR accueil-enseignant-actions §3.4 : la barre du haut, et la <dialog> plein écran qu'elle ouvrait, n'est plus qu'à l'accueil, où
  # elle s'efface sous lg devant le bandeau. À 390 px, l'avatar du bandeau mène à « Mon compte » en page, qui commence par son retour.
  test "CA-T6, CA-H1: at 390 px, the avatar of the home band leads to « Mon compte » with its counters, and back to the home" do
    maths = create_material(name: "Mathématiques", shortname: "Maths")
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré", school: create_school(name: "Lycée moderne 2", sigle: "LM2"), materials: [ maths ])

    with_mobile_viewport do
      visit profile_path
      assert_no_selector "header.sticky", visible: :visible
      assert_no_selector TRIGGER, visible: :all

      visit teacher_home_path
      assert_no_selector "header.sticky", visible: :visible
      find("header.teacher-band a[href='#{teacher_menu_path}']").click

      assert_current_path teacher_menu_path
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      within("#teacher_menu") do
        assert_text "Awa Traoré"
        assert_text "Maths · LM2"
        assert_equal [ tn(:profile), tn("account_panel.entries.secret"),
                       "#{tn('account_panel.entries.add_material')} #{I18n.t('shared.navigation.account_panel.counter.under', used: 1, max: 3)}",
                       "#{tn('account_panel.entries.add_school')} #{I18n.t('shared.navigation.account_panel.counter.under', used: 1, max: 3)}" ],
                     all("nav a", minimum: 4).map { it.text.squish }.first(4)
        assert_no_link "Inviter un collègue"
        assert_button tn(:sign_out)
      end
      find("main nav[aria-label='#{I18n.t('components.back_link.label')}'] a").click
      assert_current_path teacher_home_path
    end
  end

  # UDR-0054, amendement « survol » ; chantier infobulle-badges-hors-ecran. Une fois glissé, le tiroir ne garde aucun
  # transform : sinon il devient le repère des descendants en position fixe (infobulles au survol) et les décale.
  test "once open, the account panel keeps no transform" do
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré")

    # UDR accueil-enseignant-actions §3.4 : la <dialog> de l'en-tête ne s'ouvre plus que sur l'accueil, dès lg.
    with_mobile_viewport([ 1280, 900 ]) do
      visit teacher_home_path
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
