require "application_system_test_case"

# CA-J5 and CA-J6 (UDR « écrans enseignant sans répétition » §3.9, « Sur ordinateur »), in a real browser at 1280 px:
# two equal columns, the teacher-colour panel on the left says « Bienvenue » once and stays on every step, the steps
# sit on the right in 28 rem at most; an invite link opens step 2. CA-G12 (lot P0, option A): the teacher's top bar (yellow strip,
# logo, « Lnclass », « Besoin d'aide ? », no avatar) is above the two columns from lg, the page does not overflow at 1280 and
# 1024 px, and the second « Besoin d'aide ? » of the right column is gone; at 390 px nothing changes.
class Identity::TeacherRegistrationDesktopTest < ApplicationSystemTestCase
  PAGE = "identity.teacher_registrations.new".freeze

  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Moderne de Cocody")
    create_material(name: "SVT", shortname: "SVT")
  end

  def box(selector) = page.evaluate_script("(({ left, top, width }) => ({ left: Math.round(left), top: Math.round(top), width: Math.round(width) }))(document.querySelector(#{selector.to_json}).getBoundingClientRect())")

  test "CA-J5: two equal columns, one welcome on the left, the steps on 28 rem at most" do
    page.current_window.resize_to(1280, 900)
    visit new_teacher_registration_path

    assert_selector "#signup-panel", text: I18n.t("#{PAGE}.welcome"), count: 1
    assert_text I18n.t("#{PAGE}.welcome"), count: 1
    assert_no_selector "#signup-header a[aria-label]"
    assert_equal 640, box("#signup-panel")["width"]
    assert_operator box("#signup-progress")["width"], :<=, 448
    assert_operator box("#signup-progress")["left"], :>=, 640
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  def overflow = page.evaluate_script("document.documentElement.scrollHeight - innerHeight")

  test "CA-G12: from lg the top bar is above the columns, with one help and no avatar, and the page does not overflow" do
    [ [ 1280, 900 ], [ 1024, 768 ] ].each do |size|
      page.current_window.resize_to(*size)
      visit new_teacher_registration_path

      within("header") do
        assert_selector "div.bg-teacher.h-1", visible: true
        assert_selector "a img[src*='logo']", visible: true
        assert_text "Lnclass"
        assert_selector "a[aria-controls=help-sheet-bar]", text: I18n.t("shared.help_sheet.trigger"), visible: true
        assert_no_selector "[aria-controls=account_panel]", visible: :all
      end
      assert_no_selector "#signup-header", visible: true
      assert_selector "a[aria-controls=help-sheet]", count: 0, visible: true
      assert_operator box("#signup-panel")["top"], :>=, 64
      assert_operator overflow, :<=, 0, "la page déborde à #{size.first} px"
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "CA-G12: at 390 px the registration keeps its own logo and help, without the top bar" do
    with_mobile_viewport do
      visit new_teacher_registration_path

      assert_no_selector "header", visible: true
      within("#signup-header") do
        assert_selector "a img[src*='logo']", visible: true
        assert_selector "a[aria-controls=help-sheet]", text: I18n.t("shared.help_sheet.trigger"), visible: true
      end
    end
  end

  test "CA-J6: an invite link opens step 2, the panel stays" do
    page.current_window.resize_to(1280, 900)
    referrer = create_teacher(school: @school)
    visit teacher_invite_link_path(Orm::TeacherSchool.find_by!(teacher: referrer).invite_token)

    assert_selector "#signup-step-counter", text: I18n.t("#{PAGE}.step_counter", n: 2)
    assert_selector "#signup-panel", text: I18n.t("#{PAGE}.welcome"), count: 1
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
