require "application_system_test_case"

# CA-J1 to CA-J4 (UDR « écrans enseignant sans répétition » §3.9), in a real browser, at 390 px: one form cut in three steps
# by the student's signup_steps_controller. Without a link: step 1 (school) moves on by itself once the school is chosen;
# an invite link opens step 2 with the school recap; step 2 asks for one subject only; the account is created on step 3.
# The number is cleaned while typed and the secret code says live whether the confirmation matches (IE-17, IE-19).
class Identity::TeacherSignupTest < ApplicationSystemTestCase
  PAGE = "identity.teacher_registrations.new".freeze
  FORM = "identity.teacher_registrations.form".freeze

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

  def assert_step(number)
    assert_selector "#signup-step-counter", text: t("#{PAGE}.step_counter", n: number)
    assert_equal [ number ], page.all("fieldset[data-classroom--signup-steps-target=step]", visible: :visible).map { it["data-step"].to_i }
  end

  # Step 2, in the order of the page; the move to step 3 comes a second after the number is complete.
  def fill_person(contact: "0701020304")
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Aya  Marie"
    choose t("identity.teacher_registrations.form.genders.female")
    paste "teacher_registration[contact]", contact
  end

  def assert_signed_up(channel)
    assert_toast t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_home_path
    teacher = Orm::User.find_by!(contact: "0701020304", role: "teacher")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher:).pluck(:school_id, :primary)
    assert_equal [ Orm::Material.find_by!(name: "SVT").id ], Orm::TeacherSchoolMaterial.where(teacher:).pluck(:material_id)
    assert_equal channel, Orm::TeacherProfile.find_by!(user: teacher).joined_via
  end

  test "CA-J1, CA-J3, CA-J4: without a link, step 1 moves on by itself, step 2 asks for one subject, the account is created" do
    with_mobile_viewport do
      visit new_teacher_registration_path

      assert_step 1
      assert_selector "#signup-welcome", text: t("#{PAGE}.welcome")
      assert_selector "#signup-back", visible: :hidden
      assert_no_button "Continuer"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "la page déborde en largeur"
      select "Abidjan 1", from: "teacher_registration[drena_public_id]"
      assert_step 1
      select "Lycée Moderne de Cocody", from: "teacher_registration[school_public_id]"

      assert_step 2
      assert_selector "#signup-live", text: t("#{PAGE}.step_announce", n: 2, title: t("#{FORM}.you")), visible: :all
      assert_no_selector "#school-preview"
      assert_selector "fieldset[data-step='2'] select", count: 1
      assert_no_field "teacher_registration[second_material_slug]"
      assert_text t("#{FORM}.material_hint")
      assert_no_text "Autre matière"
      fill_person
      assert_field "teacher_registration[contact]", with: "0701020304"

      assert_step 3
      assert_selector "#teacher-registration-submit ~ p a[href='#{terms_path}']"
      fill_in "teacher_registration[pin]", with: "4821"
      fill_in "teacher_registration[pin_confirmation]", with: "4822"
      assert_selector "#pin_match_status.text-error", text: t("#{FORM}.pin_match.ko")
      fill_in "teacher_registration[pin_confirmation]", with: "4821"
      assert_selector "#pin_match_status.text-success", text: t("#{FORM}.pin_match.ok")
      click_on t("#{FORM}.submit")

      assert_signed_up "standard"
    end
  end

  test "CA-J2: an invite link opens step 2 with the school recap; an unknown link warns on step 1" do
    referrer = create_teacher(school: @school)
    token = Orm::TeacherSchool.find_by!(teacher: referrer).invite_token

    visit teacher_invite_link_path("cccccccccccc")
    assert_step 1
    assert_selector "#invite-link-invalid", text: t("#{PAGE}.invite_invalid")
    assert_field "teacher_registration[drena_public_id]"

    with_mobile_viewport do
      visit teacher_invite_link_path(token)

      assert_step 2
      assert_selector "#signup-welcome", text: t("#{PAGE}.welcome")
      assert_selector "#signup-back", visible: :hidden
      within "#school-preview" do
        assert_text "Lycée Moderne de Cocody"
        assert_text "Abidjan 1"
        assert_link t("identity.teacher_registrations.school_preview.other_school"), href: new_teacher_registration_path
      end
      assert_no_field "teacher_registration[drena_public_id]"
      fill_person(contact: "+225 07 01 02 03 04")

      assert_step 3
      fill_in "teacher_registration[pin]", with: "4821"
      fill_in "teacher_registration[pin_confirmation]", with: "4821"
      click_on t("#{FORM}.submit")

      assert_signed_up "colleague"
    end
    assert_equal [ referrer.id ], Orm::Referral.pluck(:referrer_id)
  end
end

# IE-17, IE-19 and UDR-0079 §2.4: without JavaScript, the DRENA is sent by its own GET form, the server cleans the number
# and refuses different codes. Chrome runs with scripts disabled.
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
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Aya Marie"
    choose I18n.t("identity.teacher_registrations.form.genders.female")
    fill_in "teacher_registration[contact]", with: "+225 07 01 02 03 04"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "1357"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_selector "#teacher_registration_pin_confirmation_error"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_home_path
    teacher = Orm::User.find_by!(contact: "0701020304")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
  end
end
