require "application_system_test_case"

# CA-H7, CA-G11, CA-G12 (UDR « écrans enseignant sans répétition » §3.4, lot P0 de mvp-teacher-student). At 1280 px, the avatar
# of the header opens « Mon compte » as a 400 px panel on the right; at 3 on 3, « Ajouter une matière » opens « Mes matières » in
# the same panel, without leaving the page below; a removal keeps the panel open on « 2 sur 3 »; « ‹ Mon compte » brings the
# menu back. The top bar has the yellow strip, the logo, « Besoin d'aide ? » then the avatar; the sidebar starts with the profile
# block (avatar, name, « Maths · PC · SVT · LM2 »), then the three entries, the active one light blue with blue text, without
# « Inviter » (CA-G12). At 390 px nothing moves: no strip, no logo, no profile block, and the entry leaves for the page.
class Shared::TeacherAccountPanelDesktopTest < ApplicationSystemTestCase
  DESKTOP_VIEWPORT = [ 1280, 900 ].freeze
  TRIGGER = "header a[aria-controls=account_panel]".freeze
  PANEL = "dialog#account_panel".freeze

  setup do
    materials = [ create_material(name: "Mathématiques", shortname: "Maths"), create_material(name: "Physique-Chimie", shortname: "PC"),
                  create_material(name: "SVT", shortname: "SVT") ]
    sign_in_as create_teacher(first_name: "Awa", last_name: "Traoré", school: create_school(name: "Lycée moderne 2", sigle: "LM2"), materials:)
  end

  def tn(key, **) = I18n.t("shared.navigation.#{key}", **)

  test "CA-H7, CA-G11, CA-G12: at 1280 px, « Mes matières » opens in the 400 px panel and a removal keeps it open on 2 sur 3" do
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      # CA-G11: the active entry of the sidebar is light blue with blue text, never yellow.
      visit courses_path
      assert_selector "aside nav a.bg-brand-soft.text-brand-strong", text: tn(:courses), count: 1
      assert_no_selector "aside .bg-teacher"
      visit profile_path

      # CA-G12: the top bar, then the sidebar, which starts with the profile block.
      within("header") do
        assert_selector "div.bg-teacher.h-1", visible: true
        assert_selector "a img[src*='logo']", visible: true
        assert_text "Lnclass"
        help = find_link(I18n.t("shared.help_sheet.trigger"))
        avatar = find(TRIGGER)
        assert_operator help.evaluate_script("this.getBoundingClientRect().right"), :<=, avatar.evaluate_script("this.getBoundingClientRect().left")
        assert_in_delta 40, avatar.find("[role=img]").evaluate_script("this.getBoundingClientRect().width"), 1
        assert_no_text "Awa Traoré"
      end
      within("aside") do
        assert_equal [ "AT", "Awa Traoré", "Maths · PC · SVT · LM2" ], find("div.rounded-card", match: :first).text.split("\n")
        assert_equal [ tn(:home), tn(:classrooms), tn(:courses) ], all("nav a").map { it.text.squish }
        assert_no_text "Inviter"
        assert_no_text "Parrainage"
      end
      find(TRIGGER).click
      panel = find("#{PANEL}[open]", visible: true)
      box = page.evaluate_script("(r => [r.width, r.height, r.right, innerWidth, innerHeight])(document.getElementById('account_panel').getBoundingClientRect())")
      assert_in_delta 400, box[0], 1
      assert_in_delta box[3], box[2], 1
      assert_in_delta box[4], box[1], 1

      within(panel) { click_link "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.full.materials', used: 3, max: 3)}" }
      within(panel) do
        assert_selector "h1", text: I18n.t("identity.profile_materials.show.title")
        assert_selector "#teacher_materials li", count: 3
        find("#teacher_material_svt").click_button I18n.t("identity.profile_materials.show.remove")
        assert_no_selector "#teacher_material_svt"
        assert_text I18n.t("identity.profile_materials.show.count", count: 2, max: 3)
      end
      assert_current_path profile_path
      assert_selector "#{PANEL}[open]", visible: true

      within(panel) { click_link I18n.t("identity.profile_materials.show.back") }
      within(panel) do
        assert_selector "h2", text: tn("account_panel.title")
        assert_text(/#{tn('account_panel.entries.add_material')}\s+#{tn('account_panel.counter.under', used: 2, max: 3)}/)
        assert_no_selector "h1"
      end
      assert_current_path profile_path

      # The page below only follows when the panel closes: the sidebar block loses the removed subject.
      within("aside") { assert_text "Maths · PC · SVT · LM2" }
      within(panel) { find("button[aria-label='#{I18n.t('components.modal.close')}']").click }
      assert_no_selector "#{PANEL}[open]", visible: true
      within("aside") do
        assert_text "Maths · PC · LM2"
        assert_no_text "SVT"
      end
    end
  end

  test "a school left in the panel, the current one included, shows on the page below when the panel closes" do
    current = Orm::School.find_by!(sigle: "LM2")
    teacher = Orm::User.find_by!(first_name: "Awa")
    others = [ create_school(name: "Collège Saint-Michel", sigle: "CSM"), create_school(name: "Collège Notre-Dame", sigle: "CND") ]
    others.each { add_teacher_school(teacher, it) }
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit profile_path
      within("aside") { assert_text "LM2" }
      find(TRIGGER).click
      panel = find("#{PANEL}[open]", visible: true)
      within(panel) { click_link "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.full.schools', used: 3, max: 3)}" }
      within(panel) do
        assert_selector "#teacher_schools li", count: 3
        within("#teacher_school_#{current.public_id}") { click_button I18n.t("school.teacher_schools.index.leave") }
        click_button I18n.t("school.teacher_schools.index.leave_confirm")
        assert_no_selector "#teacher_school_#{current.public_id}"
        assert_text I18n.t("school.teacher_schools.index.count", count: 2, max: 3)
      end
      assert_selector "#{PANEL}[open]", visible: true
      within("aside") { assert_text "LM2" }

      within(panel) { find("button[aria-label='#{I18n.t('components.modal.close')}']").click }
      assert_no_selector "#{PANEL}[open]", visible: true
      within("aside") do
        assert_no_text "LM2"
        assert_text(/CSM|CND/)
      end
    end
  end

  # Review of P0: a response without the frame of the panel (here the 404 of a school already left on another device) must not
  # write « Content missing » in the panel: the error page shows whole, in French.
  test "at 1280 px, leaving a school already left elsewhere shows the error page, not « Content missing » in the panel" do
    teacher = Orm::User.find_by!(first_name: "Awa")
    gone = create_school(name: "Collège Saint-Michel", sigle: "CSM")
    [ gone, create_school(name: "Collège Notre-Dame", sigle: "CND") ].each { add_teacher_school(teacher, it) }
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit profile_path
      find(TRIGGER).click
      within(find("#{PANEL}[open]", visible: true)) do
        click_link "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.full.schools', used: 3, max: 3)}"
        assert_selector "#teacher_schools li", count: 3
        Orm::TeacherSchool.where(teacher:, school: gone).delete_all
        within("#teacher_school_#{gone.public_id}") { click_button I18n.t("school.teacher_schools.index.leave") }
        click_button I18n.t("school.teacher_schools.index.leave_confirm")
      end

      assert_text I18n.t("errors.not_found.title"), wait: 5
      assert_no_text "Content missing"
      assert_no_selector "#{PANEL}[open]", visible: true
    end
  end

  # Review of P0: a cut network on « Retirer » says so in the panel (role=alert, French), changes nothing, and the next try works.
  test "at 1280 px, a cut network on « Retirer » says so in the panel, for a subject then for a school, and a new try works" do
    teacher = Orm::User.find_by!(first_name: "Awa")
    [ create_school(name: "Collège Saint-Michel", sigle: "CSM"), create_school(name: "Collège Notre-Dame", sigle: "CND") ].each { add_teacher_school(teacher, it) }
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit profile_path
      find(TRIGGER).click
      panel = find("#{PANEL}[open]", visible: true)
      execute_script(<<~JS)
        const original = window.fetch
        window.networkCut = true
        window.fetch = (input, init) => (window.networkCut && init?.method?.toUpperCase() !== "GET" ? Promise.reject(new TypeError("Failed to fetch")) : original(input, init))
      JS
      failed = tn("account_panel.request_failed")

      within(panel) { click_link "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.full.materials', used: 3, max: 3)}" }
      within(panel) { find("#teacher_material_svt").click_button I18n.t("identity.profile_materials.show.remove") }
      within(panel) do
        assert_selector "[role=alert]", text: failed, count: 1
        assert_selector "#teacher_materials li", count: 3
      end
      within(panel) { find("#teacher_material_svt").click_button I18n.t("identity.profile_materials.show.remove") }
      within(panel) { assert_selector "[role=alert]", text: failed, count: 1 }

      within(panel) { click_link I18n.t("identity.profile_materials.show.back") }
      within(panel) { click_link "#{tn('account_panel.entries.add_school')} #{tn('account_panel.counter.full.schools', used: 3, max: 3)}" }
      within(panel) do
        assert_selector "#teacher_schools li", count: 3
        assert_no_selector "[role=alert]"
        within("#teacher_school_#{Orm::School.find_by!(sigle: 'CSM').public_id}") { click_button I18n.t("school.teacher_schools.index.leave") }
        click_button I18n.t("school.teacher_schools.index.leave_confirm")
        assert_selector "[role=alert]", text: failed, count: 1
        assert_selector "#teacher_schools li", count: 3
        assert_no_selector "dialog[open] dialog[open]"
      end
      assert_selector "#{PANEL}[open]", visible: true

      execute_script("window.networkCut = false")
      within(panel) do
        within("#teacher_school_#{Orm::School.find_by!(sigle: 'CSM').public_id}") { click_button I18n.t("school.teacher_schools.index.leave") }
        click_button I18n.t("school.teacher_schools.index.leave_confirm")
        assert_selector "#teacher_schools li", count: 2
        assert_no_selector "[role=alert]", text: failed
      end
    end
  end

  test "at 1280 px, each screen of the panel takes the keyboard focus on its title, and the panel still closes back to the avatar" do
    with_mobile_viewport(DESKTOP_VIEWPORT) do
      visit profile_path
      find(TRIGGER).click
      panel = find("#{PANEL}[open]", visible: true)

      within(panel) { click_link "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.full.materials', used: 3, max: 3)}" }
      assert_selector "#{PANEL} h1:focus", text: I18n.t("identity.profile_materials.show.title")

      # A removal reloads the screen in the frame: the focus goes back to its title, inside the dialog.
      within(panel) { find("#teacher_material_svt").click_button I18n.t("identity.profile_materials.show.remove") }
      assert_no_selector "#teacher_material_svt"
      assert_selector "#{PANEL} h1:focus", text: I18n.t("identity.profile_materials.show.title")

      within(panel) { click_link I18n.t("identity.profile_materials.show.back") }
      assert_selector "#{PANEL} [data-panel-focus-title]:focus", text: "Awa Traoré"

      page.send_keys :escape
      assert_no_selector "#{PANEL}[open]", visible: true
      assert_selector "#{TRIGGER}:focus"
    end
  end

  test "at 390 px, the entry at 3 sur 3 still leaves for the page « Mes matières »" do
    with_mobile_viewport do
      visit profile_path
      assert_no_selector "header div.bg-teacher", visible: true
      assert_no_selector "header img[src*='logo']", visible: true
      assert_no_selector "aside", visible: true
      find(TRIGGER).click
      within("#{PANEL}[open]") do
        click_link "#{tn('account_panel.entries.add_material')} #{tn('account_panel.counter.full.materials', used: 3, max: 3)}"
      end

      assert_current_path profile_materials_path
      assert_no_selector "#{PANEL}[open]", visible: true
      assert_selector "h1", text: I18n.t("identity.profile_materials.show.title")
    end
  end
end
