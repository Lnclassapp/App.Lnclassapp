require "application_system_test_case"

# CA-J5 and CA-J6 (UDR « écrans enseignant sans répétition » §3.9, « Sur ordinateur »), in a real browser at 1280 px:
# two equal columns, the teacher-colour panel on the left says « Bienvenue » once and stays on every step, the steps
# sit on the right in 28 rem at most; an invite link opens step 2.
class Identity::TeacherRegistrationDesktopTest < ApplicationSystemTestCase
  PAGE = "identity.teacher_registrations.new".freeze

  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Moderne de Cocody")
    create_material(name: "SVT", shortname: "SVT")
  end

  def box(selector) = page.evaluate_script("(({ left, width }) => ({ left: Math.round(left), width: Math.round(width) }))(document.querySelector(#{selector.to_json}).getBoundingClientRect())")

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
