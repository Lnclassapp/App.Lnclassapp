require "application_system_test_case"

# ADR-0050, ADR-0031: sign-in in a real browser; a failure re-renders the form in 422 without reloading the page.
class Identity::SignInTest < ApplicationSystemTestCase
  # The role homes are drawn, their controllers belong to later lots. Until those are merged, a stand-in
  # answers on the route (Turbo keeps the sign-in URL when a redirect ends in an error); a merged
  # controller is autoloadable, so the stand-in steps aside by itself.
  HOMES = {
    "Classroom::StudentHomesController" => "AuthenticatedController",
    "Classroom::TeacherHomesController" => "AuthenticatedController",
    "Teams::HomesController" => "Teams::BaseController"
  }.freeze

  HOMES.each do |name, parent|
    next if Object.const_defined?(name)

    namespace = name.deconstantize.split("::").inject(Object) do |scope, part|
      scope.const_defined?(part, false) ? scope.const_get(part, false) : scope.const_set(part, Module.new)
    end
    namespace.const_set(name.demodulize, Class.new(parent.constantize) { def show = render(html: "home", layout: true) })
  end

  test "a wrong PIN shows one message in the form, without reloading the page" do
    student = create_student
    visit new_session_path

    assert_no_page_reload do
      fill_in "session[contact]", with: student.contact
      fill_in "session[pin]", with: "1357"
      click_on I18n.t("identity.sessions.new.submit")

      assert_selector "[role=alert]", text: "Numéro ou code secret incorrect."
    end
    assert_field "session[contact]", with: student.contact
    assert_field "session[pin]", with: ""
  end

  test "a student with a classroom lands on the student home" do
    sign_in_as create_student(classroom: create_classroom)

    assert_arrived_on student_home_path
  end

  test "a teacher lands on the teacher home" do
    sign_in_as create_teacher

    assert_arrived_on teacher_home_path
  end

  test "a school admin lands on the classrooms of their school, as before" do
    sign_in_as create_school_admin

    assert_arrived_on school_admin_classrooms_path
  end

  test "a team member goes through the second factor without a click, then reaches the team home" do
    member = create_team_member
    visit new_session_path
    fill_in "session[contact]", with: member.contact
    fill_in "session[pin]", with: "2468"
    click_on I18n.t("identity.sessions.new.submit")

    assert_selector "#second-factor-form", wait: SIGN_IN_WAIT
    assert_current_path new_identity_second_factor_path
    # UDR-0054 §3.6: the code leaves by itself at the sixth digit.
    assert_no_page_reload do
      fill_in "second_factor[code]", with: "000000"

      assert_selector "#second_factor_code_error", text: "Code incorrect."
    end

    fill_in "second_factor[code]", with: ROTP::TOTP.new(member.totp_secret).now

    assert_arrived_on team_home_path
  end

  test "the same journey on a 390 px screen" do
    student = create_student
    member = create_team_member

    with_mobile_viewport do
      visit new_session_path

      assert_no_page_reload do
        fill_in "session[contact]", with: student.contact
        fill_in "session[pin]", with: "1357"
        click_on I18n.t("identity.sessions.new.submit")

        assert_selector "[role=alert]", text: "Numéro ou code secret incorrect."
      end

      sign_in_as student

      assert_arrived_on pending_account_path
      assert_toast "Connexion réussie"

      sign_out
      sign_in_with_second_factor member

      assert_arrived_on team_home_path
    end
  end

  # UDR-0060 §3.10, UDR-0057: the two entry screens pass the rule at 390 px, for every role.
  test "at 390 px, the sign-in and the forgotten PIN show one column, one title and one action" do
    with_mobile_viewport do
      visit new_session_path

      assert_selector "h1", text: "Connexion", count: 1
      assert_no_text "Heureux de vous revoir"
      assert_single_primary_action scope: "main"
      assert_blocks_above_fold "main > *", max: 1
      assert_no_text "4 chiffres"
      find("details summary", text: "Aide : Code secret").click
      assert_text "Code secret de 4 chiffres, choisi à l'inscription."
      assert_operator tap_height(find_link(I18n.t("identity.sessions.new.forgot_pin"))), :>=, 48

      click_on I18n.t("identity.sessions.new.forgot_pin")

      assert_selector "h1", text: "Code secret oublié", count: 1
      assert_text "Saisissez le code de récupération remis par votre enseignant ou par l'équipe."
      assert_single_primary_action scope: "main"
      assert_blocks_above_fold "main > *", max: 1
      assert_blocks_above_fold "main > div > *", max: 3
      assert_no_text "8 chiffres"
      find("details summary", text: "Aide : Code de récupération").click
      assert_text "8 chiffres, valable 15 minutes."
    end
  end

  test "from 1 024 px, the sign-in keeps its welcome column beside the form" do
    visit new_session_path

    assert_selector "main > section.bg-brand-soft", text: "Heureux de vous revoir"
    assert_selector "h1", text: "Connexion", count: 1
    assert_single_primary_action scope: "main"
  end

  private

  def tap_height(element)
    page.evaluate_script("arguments[0].getBoundingClientRect().height", element)
  end

  # The code leaves by itself at the sixth digit (UDR-0054 §3.6): no click on « Vérifier », which may be gone already.
  def sign_in_with_second_factor(member)
    visit new_session_path
    fill_in "session[contact]", with: member.contact
    fill_in "session[pin]", with: "2468"
    click_on I18n.t("identity.sessions.new.submit")
    fill_in "second_factor[code]", with: ROTP::TOTP.new(member.totp_secret).now, wait: SIGN_IN_WAIT
  end

  # Every home renders the shell: its main region is there before the URL is checked.
  def assert_arrived_on(path)
    assert_selector "main#main", wait: SIGN_IN_WAIT
    assert_current_path path
  end
end
