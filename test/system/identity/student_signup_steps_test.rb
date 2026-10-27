require "application_system_test_case"

# CA-C1 to CA-C6, CA-C8, CA-C9 (UDR « inscription élève en trois étapes »), in a real browser (1400 px wide: the computer layout,
# the blue panel of §3.5 bis; the phone has its own case at 390 px): one form cut in three steps in the page.
# The class code opens step 1 and moves on by itself once it is recognised; the link lands on step 2; the cascade (« Je n'ai
# pas de code ») moves on when a classroom is touched; step 2 moves on about a second after the last key, announced in an
# aria-live region; « ‹ Retour » loses nothing; a server error reopens the step that holds it. There is no « Continuer ».
class Identity::StudentSignupStepsTest < ApplicationSystemTestCase
  FORM = "classroom.student_registrations.form".freeze
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena:, name: "Collège Moderne 1 de Tiassalé")
    @classroom = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3e B")
    @code = @classroom.reload.join_code
  end

  test "CA-C1, CA-C2: the code opens step 1, a recognised code moves to step 2 with the class recap, and « Ce n'est pas ta classe ? » comes back" do
    visit new_student_registration_path

    assert_step 1
    # CA-C8: the panel (360 px, the same at every step) replaces the welcome card and the bar.
    assert_panel_step 1
    assert_equal 360, evaluate_script("document.querySelector('#signup-panel').getBoundingClientRect().width").round
    assert_no_selector "#signup-welcome", visible: :visible
    assert_no_selector "#signup-progress", visible: :visible
    assert_selector "#signup-back", visible: :hidden
    assert_no_button "Continuer"
    assert_selector "fieldset[data-step='2']", visible: :hidden
    assert_no_selector "#signup-cascade", visible: :visible

    fill_in "student_registration[join_code]", with: @code.downcase

    assert_step 2
    # CA-C9: the class found is in the panel under step 1, and not repeated above the form.
    assert_panel_step 2
    assert_selector "#signup-panel li[data-step='1'] #signup-panel-recap", text: /3e B.*Collège Moderne 1 de Tiassalé/m
    assert_no_selector "#signup-classroom-recap", visible: :visible
    assert_selector "#signup-live", text: I18n.t("#{FORM}.step_announce", n: 2, title: I18n.t("#{FORM}.you")), visible: :all
    assert_selector "legend", text: I18n.t("#{FORM}.you"), obscured: false
    assert_equal "legend", page.evaluate_script("document.activeElement.tagName").downcase
    assert_selector "#signup-back", visible: :visible

    click_on I18n.t("#{FORM}.other_classroom")

    assert_step 1
    assert_field "student_registration[join_code]", with: ""
    assert_unchecked_field I18n.t("#{FORM}.no_code")
  end

  test "CA-B3: an unknown code stays on step 1 with the message under the field" do
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: "zzzzzz"

    assert_selector "#classroom-code-unknown", text: I18n.t("classroom.classroom_codes.show.unknown")
    assert_step 1
    assert_selector "#student_registration_join_code[aria-invalid=true]"

    fill_in "student_registration[join_code]", with: "zzzzz"
    assert_no_selector "#classroom-code-unknown"
  end

  # Review of #295: a cut network (fetch rejected) or a 5xx without the frame must not leave « Vérification… » on screen for ever,
  # nor replace the signup page by the error page; typing again checks again.
  test "a failed code check (network, then 500) stays on step 1 with a short message, and a new typing checks again" do
    visit new_student_registration_path
    execute_script(<<~JS)
      const original = window.fetch
      window.codeCheckMode = "network"
      window.fetch = (input, init) => {
        if (!String(input?.url || input).includes("/classroom-codes/")) return original(input, init)
        return window.codeCheckMode === "network" ? Promise.reject(new TypeError("Failed to fetch"))
          : window.codeCheckMode === "error" ? Promise.resolve(new Response("<html><body>Erreur</body></html>", { status: 500, headers: { "Content-Type": "text/html" } }))
          : original(input, init)
      }
    JS

    { "network" => "zzzzzz", "error" => "zzzzzy" }.each do |mode, code|
      execute_script("window.codeCheckMode = '#{mode}'")
      fill_in "student_registration[join_code]", with: code

      assert_selector "#classroom-code-check-failed", text: I18n.t("#{FORM}.check_failed")
      assert_no_selector "#signup-code-checking", visible: :visible
      assert_no_selector "turbo-frame#classroom_code_preview[src]"
      assert_selector "#student_registration_join_code[aria-describedby~=classroom_code_preview]"
      assert_current_path new_student_registration_path
      assert_step 1
    end

    execute_script("window.codeCheckMode = 'ok'")
    fill_in "student_registration[join_code]", with: @code

    assert_step 2
  end

  test "CA-C4, CA-C5: step 2 moves on a second after the last key, « Retour » keeps the fields, and the account is created with way « code »" do
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2

    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    assert_panel_step 3
    assert_selector "#signup-live", text: I18n.t("#{FORM}.step_announce", n: 3, title: I18n.t("#{FORM}.security")), visible: :all

    click_on I18n.t("#{FORM}.back")

    assert_step 2
    assert_panel_step 2
    assert_field "student_registration[last_name]", with: "KOUASSI"
    assert_field "student_registration[contact]", with: "0701020304"
    assert_checked_field I18n.t("genders.female")
    assert_step 2, settle: 1.5

    fill_in "student_registration[contact]", with: "0701020305"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path
    student = Orm::User.find_by!(contact: "0701020305", role: "student")
    assert_equal [ [ @classroom.id, "code" ] ], Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :joined_via)
  end

  test "CA-C4: the move does not happen while a field is incomplete, nor in the middle of a typing" do
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2

    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "070102030"

    assert_step 2, settle: 1.6
  end

  test "CA-C3: the classroom link lands on step 2 with the recap, the welcome card and no « Retour »" do
    visit join_classroom_path(@classroom.reload.link_token)

    assert_step 2
    assert_panel_step 2
    assert_selector "#signup-panel #signup-panel-recap", text: /3e B/
    assert_no_selector "#signup-classroom-recap", visible: :visible
    assert_selector "#signup-back", visible: :hidden
    assert_no_selector "fieldset[data-step='1']", visible: :all
    assert_link I18n.t("#{FORM}.other_classroom")
  end

  # One journey for both: the cascade itself, and the code typed before it, which must not win once the box is checked.
  test "UDR §3.2: a valid code for class X, then « Je n'ai pas de code »: the code is gone, class Y touched moves to step 2, the student enters Y, way « standard »" do
    other = create_classroom(school: @school, level: @classroom.level, name: "3e C")
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2
    click_on I18n.t("#{FORM}.back")
    assert_step 1

    check I18n.t("#{FORM}.no_code"), allow_label_click: true
    assert_no_field "student_registration[join_code]"
    select "Abidjan 1", from: "student_registration[drena_public_id]"
    select "Collège Moderne 1 de Tiassalé", from: "student_registration[school_public_id]"
    within("turbo-frame#picker_levels") { choose "3ème" }
    within("turbo-frame#picker_classrooms") { choose "3e C" }

    assert_step 2
    assert_no_selector "#signup-classroom-recap", visible: :visible
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_current_path student_home_path
    student = Orm::User.find_by!(contact: "0701020304")
    assert_equal [ [ other.id, "standard" ] ], Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :joined_via)
  end

  test "CA-C6: a number already used reopens step 2 with the error under the field" do
    create_student(contact: "0701020304", classroom: @classroom)
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_step 2
    assert_selector "#student_registration_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_selector "#signup-panel #signup-panel-recap", text: /3e B/
    assert_field "student_registration[last_name]", with: "KOUASSI"
  end

  # Le passage seul à l'étape 3 ôte le focus du numéro : son « change » réarme le minuteur d'une seconde. Si le 422 revient
  # avant qu'il parte, l'étape 2 rouverte par le serveur doit tenir, sans repasser à l'étape 3 par-dessus l'erreur.
  test "CA-C6: a step-2 timer still pending when the server refuses does not move past the reopened step 2" do
    create_student(contact: "0701020304", classroom: @classroom)
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    execute_script("document.getElementById('student_registration_contact').dispatchEvent(new Event('change', { bubbles: true }))")
    click_on I18n.t("#{FORM}.submit")

    assert_selector "#student_registration_contact_error", text: I18n.t("#{ERRORS}.contact.taken")
    assert_step 2, settle: 1.5
  end

  test "UDR §3.8 at 390 px: the three steps fit, every touch target is 44 px high and the progress shows the step" do
    with_mobile_viewport do
      visit new_student_registration_path
      assert_step 1
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      %w[#signup-no-code-label #student_registration_join_code].each do |selector|
        assert_operator evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().height"), :>=, 44
      end
      assert_equal [ true, false, false ], page.all("#signup-progress li", visible: :all).map { it[:class].include?("bg-brand-strong") }
    end
  end

  private

  # CA-C8: the panel says the same at every step; only the step in progress (aria-current) moves.
  def assert_panel_step(number)
    assert_selector "#signup-panel", text: "Bienvenue sur Lnclass"
    assert_selector "#signup-panel", text: I18n.t("classroom.student_registrations.new.have_account")
    assert_selector "#signup-panel a", text: I18n.t("classroom.student_registrations.new.sign_in")
    assert_equal [ number ], page.all("#signup-panel [aria-current=step]").map { it["data-step"].to_i }
  end

  def assert_step(number, settle: nil)
    sleep settle if settle
    assert_selector "#signup-step-counter", text: I18n.t("#{FORM}.step_counter", n: number)
    assert_selector "fieldset[data-step='#{number}']", visible: :visible
    assert_equal [ number ], page.all("fieldset[data-classroom--signup-steps-target=step]", visible: :visible).map { it["data-step"].to_i }
  end
end
