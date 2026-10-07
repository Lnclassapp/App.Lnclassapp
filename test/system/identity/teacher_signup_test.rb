require "application_system_test_case"

# IE-01, IE-04, IE-06, IE-09, IE-17, IE-19 (ADR-0082, UDR-0078): one sign-up page in three sections. The standard way
# chooses the DRENA, then the school, then the subject; the full name shows its split and can be corrected; the number is
# cleaned while typed; the secret code says live whether the confirmation matches. An invite link arrives with the school
# already chosen. Errors come back without reloading the page until the account exists.
class Identity::TeacherSignupTest < ApplicationSystemTestCase
  FORM = "identity.teacher_registrations.form".freeze
  ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze

  setup do
    @drena = create_drena(name: "Abidjan 1")
    @school = create_school(drena: @drena, name: "Lycée Moderne de Cocody")
    create_school(drena: @drena, name: "Lycée fermé", status: "inactive")
    create_material(name: "SVT", shortname: "SVT")
  end

  def t(key, **) = I18n.t(key, **)

  # A paste: the whole value at once, then one input event, as the browser does.
  def paste(field, text)
    execute_script("arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
                   find_field(field), text)
  end

  def choose_school
    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    select "Lycée Moderne de Cocody", from: "teacher_registration[school_public_id]"
    select "SVT", from: "teacher_registration[material_slug]"
  end

  def fill_person(full_name: "KOUASSI Aya Marie", contact: "0501020304")
    fill_in "teacher_registration[full_name]", with: full_name
    choose t("genders.female")
    fill_in "teacher_registration[contact]", with: contact
  end

  def fill_codes(pin: "4821", confirmation: "4821")
    fill_in "teacher_registration[pin]", with: pin
    fill_in "teacher_registration[pin_confirmation]", with: confirmation
  end

  def assert_preview(last_name, first_name)
    within "#full_name_preview" do
      assert_selector "[data-identity--full-name-target=lastOut]", exact_text: last_name
      assert_selector "[data-identity--full-name-target=firstOut]", exact_text: first_name
    end
  end

  def assert_signed_up(channel)
    assert_toast t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_classrooms_path
    teacher = Orm::User.find_by!(contact: "0701020304", role: "teacher")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher:).pluck(:school_id, :primary)
    assert_equal channel, Orm::TeacherProfile.find_by!(user: teacher).joined_via
  end

  # The standard journey, the same on a phone and on a computer (IE-01, IE-17, IE-19).
  def standard_journey
    visit new_teacher_registration_path

    assert_equal [ "ÉTABLISSEMENT", "VOUS", "CODE SECRET" ], all("fieldset > legend.uppercase").map { it.text.upcase }
    assert_no_field "teacher_registration[school_code]"
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
           "la page déborde en largeur"
    assert_no_page_reload do
      choose_school
      fill_in "teacher_registration[full_name]", with: "KOUASSI  Aya Marie"

      within "#full_name_preview" do
        assert_selector "[data-identity--full-name-target=lastOut]", exact_text: "KOUASSI"
        assert_selector "[data-identity--full-name-target=firstOut]", exact_text: "Aya Marie"
      end
      choose t("genders.female")
      paste "teacher_registration[contact]", "+225 07 01 02 03 04"

      assert_field "teacher_registration[contact]", with: "0701020304"
      fill_codes(confirmation: "4822")

      assert_selector "#pin_match_status.text-error", text: t("#{FORM}.pin_match.ko")
      assert_selector "#teacher_registration_pin_confirmation[aria-invalid=true]"
      fill_in "teacher_registration[pin_confirmation]", with: "4821"

      assert_selector "#pin_match_status.text-success", text: t("#{FORM}.pin_match.ok")
      assert_no_selector "#teacher_registration_pin_confirmation[aria-invalid]"
    end
    click_on t("#{FORM}.submit")

    assert_signed_up "standard"
  end

  test "IE-01, IE-17, IE-19: the standard sign-up on a computer" do
    standard_journey
  end

  test "IE-01: the standard sign-up on a 390 px screen" do
    with_mobile_viewport { standard_journey }
  end

  test "IE-19, IE-17: the number keeps only ten digits; the status waits for four digits" do
    visit new_teacher_registration_path

    paste "teacher_registration[contact]", "(+225) 0701020304"
    assert_field "teacher_registration[contact]", with: "0701020304"
    paste "teacher_registration[contact]", "002250701020304"
    assert_field "teacher_registration[contact]", with: "0701020304"
    find_field("teacher_registration[contact]").send_keys("5", "a")
    assert_field "teacher_registration[contact]", with: "0701020304"

    fill_codes(pin: "1234", confirmation: "1235")
    assert_text t("#{FORM}.pin_match.ko")
    find_field("teacher_registration[pin_confirmation]").send_keys(:backspace)
    assert_no_selector "#pin_match_status", visible: true
    assert_no_selector "#teacher_registration_pin_confirmation[aria-invalid]"
    assert_includes find("#teacher_registration_pin_confirmation")["aria-describedby"], "pin_match_status"
  end

  test "IE-04, IE-05: a one-word name is refused without reloading; « Corriger » keeps the name in two words" do
    visit new_teacher_registration_path

    assert_no_page_reload do
      choose_school
      fill_person(full_name: "KONÉ", contact: "0701020304")
      fill_codes
      click_on t("#{FORM}.submit")

      assert_selector "#teacher_registration_full_name_error", text: t("#{ERRORS}.full_name.single_word")
    end
    fill_in "teacher_registration[full_name]", with: "KONÉ OUATTARA Awa"
    find("#name-correction summary").click

    assert_field "teacher_registration[last_name]", with: "KONÉ"
    assert_field "teacher_registration[first_name]", with: "OUATTARA Awa"
    fill_in "teacher_registration[last_name]", with: "KONÉ OUATTARA"
    fill_in "teacher_registration[first_name]", with: "Awa"

    # « Corriger » open: the preview follows the corrected fields; closed, the split of the full name.
    assert_preview "KONÉ OUATTARA", "Awa"
    find("#name-correction summary").click
    assert_preview "KONÉ", "OUATTARA Awa"
    find("#name-correction summary").click
    assert_preview "KONÉ OUATTARA", "Awa"
    fill_codes
    click_on t("#{FORM}.submit")

    assert_current_path teacher_classrooms_path
    assert_equal [ "KONÉ OUATTARA", "Awa" ], Orm::User.where(contact: "0701020304").pick(:last_name, :first_name)
  end

  test "IE-06, IE-09: a colleague's link shows the school and counts the referral; an unknown link warns" do
    referrer = create_teacher(school: @school)
    token = Orm::TeacherProfile.find_by!(user: referrer).referral_token

    visit teacher_invite_link_path("cccccccccccc")
    assert_selector "#invite-link-invalid", text: t("identity.teacher_registrations.new.invite_invalid")
    assert_field "teacher_registration[drena_public_id]"

    with_mobile_viewport do
      visit teacher_invite_link_path(token)

      within "#school-preview" do
        assert_text "Lycée Moderne de Cocody"
        assert_text "Abidjan 1"
      end
      assert_no_field "teacher_registration[drena_public_id]"
      select "SVT", from: "teacher_registration[material_slug]"
      fill_person(contact: "+225 07 01 02 03 04")
      fill_codes
      click_on t("#{FORM}.submit")

      assert_signed_up "colleague"
    end
    assert_equal [ referrer.id ], Orm::Referral.pluck(:referrer_id)
  end
end

# IE-17, IE-19 and UDR-0078 §2.4: without JavaScript, the DRENA is sent by its own GET form, the server splits the full
# name, cleans the number and refuses different codes. Chrome runs with scripts disabled.
class Identity::TeacherSignupWithoutJavascriptTest < ApplicationSystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [ 1400, 1400 ], options: { name: :chrome_without_javascript } do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    %w[--headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --blink-settings=scriptEnabled=false].each do
      options.add_argument(it)
    end
  end

  setup do
    @school = create_school(drena: create_drena(name: "Abidjan 1"), name: "Lycée Moderne de Cocody")
    create_material(name: "SVT", shortname: "SVT")
  end

  test "the whole sign-up without JavaScript" do
    visit new_teacher_registration_path

    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    click_on I18n.t("identity.teacher_registrations.school_fields.show_schools")
    select "Lycée Moderne de Cocody", from: "teacher_registration[school_public_id]"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[full_name]", with: "KOUASSI Aya Marie"
    choose I18n.t("genders.female")
    fill_in "teacher_registration[contact]", with: "+225 07 01 02 03 04"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "1357"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_selector "#teacher_registration_pin_confirmation_error"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_classrooms_path
    teacher = Orm::User.find_by!(contact: "0701020304")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
  end
end
