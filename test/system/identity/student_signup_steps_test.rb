require "application_system_test_case"

# CA-C1 to CA-C6, CA-C8, CA-C9 (UDR « inscription élève en trois étapes »), in a real browser (1400 px wide: the computer layout,
# the blue panel of §3.5 bis; the phone has its own case at 390 px): one form cut in three steps in the page.
# Step 1 is the school search cascade only (no class code, chantier entree-et-accueil-eleve-allegees CA-6): it moves on when a
# classroom is touched; the link lands on step 2; step 2 moves on a delay after the last key (1 s in production, 100 ms here), announced in an
# aria-live region; « ‹ Retour » loses nothing; a server error reopens the step that holds it. There is no « Continuer ».
class Identity::StudentSignupStepsTest < ApplicationSystemTestCase
  FORM = "classroom.student_registrations.form".freeze
  ERRORS = "activemodel.errors.models.dtos/classroom/student_registration_input.attributes".freeze

  setup do
    drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena:, name: "Collège Moderne 1 de Tiassalé")
    @classroom = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3e B")
  end

  test "CA-C1, CA-6: step 1 is the cascade only, with no class code field nor link; a classroom touched moves to step 2, « Retour » comes back" do
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
    assert_selector "#signup-cascade", visible: :visible
    # CA-6: neither the link nor the field of the class code.
    assert_no_selector "#signup-have-code", visible: :all
    assert_no_selector "#signup-code-field", visible: :all
    assert_no_field "student_registration[join_code]"

    pick_classroom
    assert_step 2
    assert_panel_step 2
    assert_selector "#signup-live", text: I18n.t("#{FORM}.step_announce", n: 2, title: I18n.t("#{FORM}.you")), visible: :all
    assert_selector "legend", text: I18n.t("#{FORM}.you"), obscured: false
    assert_equal "legend", page.evaluate_script("document.activeElement.tagName").downcase
    assert_selector "#signup-back", visible: :visible

    click_on I18n.t("#{FORM}.back")
    assert_step 1
    assert_selector "#signup-cascade", visible: :visible
  end

  test "CA-C4, CA-C5: step 2 moves on a delay after the last key, « Retour » keeps the fields, and the account is created with way « standard »" do
    visit new_student_registration_path
    pick_classroom
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
    assert_step 2, settle: signup_settle

    fill_in "student_registration[contact]", with: "0701020305"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.student_registrations.create.welcome")
    assert_current_path student_home_path
    student = Orm::User.find_by!(contact: "0701020305", role: "student")
    assert_equal [ [ @classroom.id, "standard" ] ], Orm::ClassroomStudent.where(student:).pluck(:classroom_id, :joined_via)
  end

  test "CA-C4: the move does not happen while a field is incomplete, nor in the middle of a typing" do
    visit new_student_registration_path
    pick_classroom
    assert_step 2

    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "070102030"

    assert_step 2, settle: signup_settle
  end

  test "CA-C3: the classroom link lands on step 2 with the recap, the welcome card and no « Retour »" do
    visit join_classroom_path(@classroom.reload.link_token)
    pass_student_entry

    # Chantier entree-eleve-unifiee : après l'entrée, « Toi » est la dernière des deux étapes.
    assert_selector "#signup-step-counter", text: I18n.t("#{FORM}.step_counter_entry", n: 2)
    assert_panel_step 2, entry: true
    assert_selector "#signup-panel #signup-panel-recap", text: /3e B/
    assert_no_selector "#signup-classroom-recap", visible: :visible
    assert_selector "#signup-back", visible: :hidden
    assert_no_selector "fieldset[data-step='1']", visible: :all
    assert_link I18n.t("#{FORM}.other_classroom")
  end

  test "CA-C6: a number already used reopens step 2 with the error under the field" do
    create_student(contact: "0701020304", classroom: @classroom)
    visit new_student_registration_path
    pick_classroom
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
    # The timer must still be pending when the server answers: the production delay, 1 s, not the test's 100 ms.
    with_production_signup_delay do
      create_student(contact: "0701020304", classroom: @classroom)
      visit new_student_registration_path
      assert_no_selector "[data-classroom--signup-steps-delay-value]", visible: :all
      pick_classroom
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
      assert_step 2, settle: signup_settle
    end
  end

  test "UDR §3.8 at 390 px: the three steps fit, every touch target is 44 px high and the progress shows the step" do
    with_mobile_viewport do
      visit new_student_registration_path
      assert_step 1
      assert_operator evaluate_script("document.documentElement.scrollWidth"), :<=, 390
      assert_equal [ true, false, false ], page.all("#signup-progress li", visible: :all).map { it[:class].include?("bg-brand") }
    end
  end

  private

  # CA-6: the cascade is the only way in; the school, the level, then the classroom touched.
  def pick_classroom(name = "3e B")
    choose_school "Collège Moderne 1 de Tiassalé", search: "moderne tiassale"
    within("turbo-frame#picker_levels") { choose "3ème" }
    within("turbo-frame#picker_classrooms") { choose name }
  end

  # CA-C8: the panel says the same at every step; only the step in progress (aria-current) moves.
  # entry: after the student entry, the number is known to have no account: no « Déjà un compte ? ».
  def assert_panel_step(number, entry: false)
    assert_selector "#signup-panel", text: "Bienvenue sur Lnclass"
    if entry
      assert_no_selector "#signup-panel", text: I18n.t("classroom.student_registrations.new.have_account")
    else
      assert_selector "#signup-panel", text: I18n.t("classroom.student_registrations.new.have_account")
      assert_selector "#signup-panel a", text: I18n.t("classroom.student_registrations.new.sign_in")
    end
    assert_equal [ number ], page.all("#signup-panel [aria-current=step]").map { it["data-step"].to_i }
  end

  def assert_step(number, settle: nil)
    sleep settle if settle
    assert_selector "#signup-step-counter", text: I18n.t("#{FORM}.step_counter", n: number)
    assert_selector "fieldset[data-step='#{number}']", visible: :visible
    assert_equal [ number ], page.all("fieldset[data-classroom--signup-steps-target=step]", visible: :visible).map { it["data-step"].to_i }
  end
end
