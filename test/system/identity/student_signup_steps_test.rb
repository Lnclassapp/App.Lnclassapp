require "application_system_test_case"

# CA-C1 to CA-C6 (UDR « inscription élève en trois étapes »), in a real browser: one form cut in three steps in the page.
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
    assert_selector "#signup-welcome", text: "Bienvenue sur Lnclass"
    assert_selector "#signup-back", visible: :hidden
    assert_no_button "Continuer"
    assert_selector "fieldset[data-step='2']", visible: :hidden
    assert_no_selector "#signup-cascade", visible: :visible

    fill_in "student_registration[join_code]", with: @code.downcase

    assert_step 2
    assert_selector "#signup-classroom-recap", text: /3e B.*Collège Moderne 1 de Tiassalé/m
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

  test "CA-C4, CA-C5: step 2 moves on a second after the last key, « Retour » keeps the fields, and the account is created with way « code »" do
    visit new_student_registration_path
    fill_in "student_registration[join_code]", with: @code
    assert_step 2

    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    assert_selector "#signup-live", text: I18n.t("#{FORM}.step_announce", n: 3, title: I18n.t("#{FORM}.security")), visible: :all

    click_on I18n.t("#{FORM}.back")

    assert_step 2
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
    assert_selector "#signup-classroom-recap", text: /3e B/
    assert_selector "#signup-welcome", text: "Bienvenue sur Lnclass"
    assert_selector "#signup-back", visible: :hidden
    assert_no_selector "fieldset[data-step='1']", visible: :all
    assert_link I18n.t("#{FORM}.other_classroom")
  end

  test "UDR §3.2: « Je n'ai pas de code » opens the cascade, hides the code, and a classroom touched moves to step 2" do
    visit new_student_registration_path
    check I18n.t("#{FORM}.no_code"), allow_label_click: true

    assert_no_field "student_registration[join_code]"
    select "Abidjan 1", from: "student_registration[drena_public_id]"
    select "Collège Moderne 1 de Tiassalé", from: "student_registration[school_public_id]"
    within("turbo-frame#picker_levels") { choose "3ème" }
    within("turbo-frame#picker_classrooms") { choose "3e B" }

    assert_step 2
    assert_no_selector "#signup-classroom-recap", visible: :visible
    fill_in "student_registration[last_name]", with: "KOUASSI"
    fill_in "student_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.male")
    fill_in "student_registration[contact]", with: "0701020304"
    assert_step 3
    fill_in "student_registration[pin]", with: "4821"
    fill_in "student_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_current_path student_home_path
    assert_equal [ "standard" ], Orm::ClassroomStudent.where(student: Orm::User.find_by!(contact: "0701020304")).pluck(:joined_via)
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
    assert_selector "#signup-classroom-recap", text: /3e B/
    assert_field "student_registration[last_name]", with: "KOUASSI"
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

  def assert_step(number, settle: nil)
    sleep settle if settle
    assert_selector "#signup-step-counter", text: I18n.t("#{FORM}.step_counter", n: number)
    assert_selector "fieldset[data-step='#{number}']", visible: :visible
    assert_equal [ number ], page.all("fieldset[data-classroom--signup-steps-target=step]", visible: :visible).map { it["data-step"].to_i }
  end
end
