require "application_system_test_case"

# CA-J1 to CA-J4 (UDR « écrans enseignant sans répétition » §3.9) and chantier connexion-numero-d-abord (UDR-XXXX §3.5, CA-11,
# CA-12), in a real browser, at 390 px: one form cut in three steps by the student's signup_steps_controller. Step 1, the
# number, and step 2, the secret code typed once, move on by « Continuer » once valid; step 3, the profile, holds the school
# (searched, or the recap of an invite link), one subject, the name, and « Créer mon compte ». No school code.
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

  def fill_profile
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Aya  Marie"
    choose t("identity.teacher_registrations.form.genders.female")
  end

  def assert_signed_up(channel)
    assert_toast t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_home_path
    teacher = Orm::User.find_by!(contact: "0701020304", role: "teacher")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ [ @school.id, true ] ], Orm::TeacherSchool.where(teacher:).pluck(:school_id, :primary)
    assert_equal [ Orm::Material.find_by!(name: "SVT").id ], Orm::TeacherSchoolMaterial.where(teacher:).pluck(:material_id)
    assert_equal channel, Orm::TeacherProfile.find_by!(user: teacher).joined_via
    assert Orm::User.authenticate_by(contact: "0701020304", pin: "4821")
  end

  test "CA-11, CA-J3, CA-J4: number, then the code once, then the profile with the school and one subject; the account is created" do
    with_mobile_viewport do
      visit new_teacher_registration_path(confirmed: 1)

      assert_step 1
      assert_selector "#signup-welcome", text: t("#{PAGE}.welcome")
      assert_selector "#signup-back", visible: :hidden
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "la page déborde en largeur"
      # A number short of its 10 digits holds step 1.
      paste "teacher_registration[contact]", "07010203"
      click_on t("#{FORM}.continue")
      assert_step 1
      paste "teacher_registration[contact]", "+225 07 01 02 03 04"
      assert_field "teacher_registration[contact]", with: "0701020304"
      click_on t("#{FORM}.continue")

      assert_step 2
      assert_selector "#signup-live", text: t("#{PAGE}.step_announce", n: 2, title: t("#{FORM}.security")), visible: :all
      assert_no_field "teacher_registration[pin_confirmation]"
      assert_no_selector "#teacher-registration-number"
      # Three digits hold step 2; Entrée is « Continuer ».
      fill_in "teacher_registration[pin]", with: "482"
      click_on t("#{FORM}.continue")
      assert_step 2
      fill_in "teacher_registration[pin]", with: "4821"
      find_field("teacher_registration[pin]").send_keys(:enter)

      assert_step 3
      assert_no_field "teacher_registration[school_code]"
      assert_selector "fieldset[data-step='3'] select", count: 1
      assert_text t("#{FORM}.material_hint")
      fill_in "school_q", with: "cocody"
      within("turbo-frame#school_results") { choose "Lycée Moderne de Cocody" }
      assert_step 3
      fill_profile
      assert_selector "#teacher-registration-submit ~ p a[href='#{terms_path}']"
      click_on t("#{FORM}.submit")

      assert_signed_up "standard"
    end
  end

  test "CA-12: an invite link keeps its school, recalled on the profile; an unknown link warns on step 1" do
    referrer = create_teacher(school: @school)
    token = Orm::TeacherSchool.find_by!(teacher: referrer).invite_token

    visit teacher_invite_link_path("cccccccccccc")
    assert_step 1
    assert_selector "#invite-link-invalid", text: t("#{PAGE}.invite_invalid")

    with_mobile_viewport do
      visit teacher_invite_link_path(token)

      assert_step 1
      assert_selector "#signup-welcome", text: t("#{PAGE}.welcome")
      fill_teacher_number_and_code "0701020304", "4821"
      within "#school-preview" do
        assert_text "Lycée Moderne de Cocody"
        assert_text "Abidjan 1"
        assert_link t("identity.teacher_registrations.school_preview.other_school"), href: new_teacher_registration_path
      end
      assert_no_field "school_q"
      fill_profile
      click_on t("#{FORM}.submit")

      assert_signed_up "colleague"
    end
    assert_equal [ referrer.id ], Orm::Referral.pluck(:referrer_id)
  end

  test "« Retour » from the profile goes back to the code, kept" do
    visit new_teacher_registration_path(confirmed: 1)
    fill_teacher_number_and_code "0701020304", "4821"

    click_on t("#{PAGE}.back")
    assert_step 2
    assert_field "teacher_registration[pin]", with: "4821"
  end
end

# IE-17, IE-19 and UDR-0079 §2.4: without JavaScript, the three steps are on one page; the school search is sent by its own
# GET form (search first: it does not carry the other fields), the server cleans the number and refuses a code out of format.
# Chrome runs with scripts disabled.
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
    visit new_teacher_registration_path(confirmed: 1)

    fill_in "school_q", with: "cocody"
    click_on I18n.t("school.school_searches.field.search")
    choose "Lycée Moderne de Cocody"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[last_name]", with: "KOUASSI"
    fill_in "teacher_registration[first_name]", with: "Aya Marie"
    choose I18n.t("identity.teacher_registrations.form.genders.female")
    fill_in "teacher_registration[contact]", with: "+225 07 01 02 03 04"
    fill_in "teacher_registration[pin]", with: "48a1"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_selector "#teacher_registration_pin_error"
    fill_in "teacher_registration[pin]", with: "4821"
    click_on I18n.t("identity.teacher_registrations.form.submit")

    assert_current_path teacher_home_path
    teacher = Orm::User.find_by!(contact: "0701020304")
    assert_equal [ "KOUASSI", "Aya Marie" ], [ teacher.last_name, teacher.first_name ]
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
  end
end
