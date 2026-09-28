require "application_system_test_case"

# ID-03, CE-01 to CE-03 (ADR-0057, UDR-0024, UDR-0044): a visitor signs up as a teacher with the code of their school —
# typed on /teacher-signup, or carried by the link /e/<code>, which shows the school instead of the field. A refused code
# reads the same whatever the reason; errors come back without reloading the page until the account exists.
class Identity::TeacherSignupTest < ApplicationSystemTestCase
  FORM = "identity.teacher_registrations.form".freeze
  ERRORS = "activemodel.errors.models.dtos/identity/teacher_registration_input.attributes".freeze

  setup do
    abidjan = create_drena(name: "Abidjan 1")
    @school = create_school(drena: abidjan, name: "Lycée Classique d'Abidjan", school_code: "k7m4qz")
    create_school(drena: abidjan, name: "Lycée fermé", status: "inactive", school_code: "abc234")
    create_material(name: "SVT", shortname: "SVT")
  end

  test "CE-01, CE-03: a refused code, then an unconfirmed PIN, without reloading; the right sign-up lands on the class selection" do
    visit new_teacher_registration_path

    assert_no_selector "select[name='teacher_registration[drena_public_id]']"
    assert_no_page_reload do
      fill_registration(school_code: "abc 234")
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#teacher_registration_school_code_error", text: I18n.t("#{ERRORS}.school_code.inclusion")
      assert_no_text "Lycée fermé"

      fill_in "teacher_registration[school_code]", with: "k7m 4qz"
      fill_in "teacher_registration[pin]", with: "4821"
      fill_in "teacher_registration[pin_confirmation]", with: "1357"
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#teacher_registration_pin_confirmation_error",
                      text: I18n.t("#{ERRORS}.pin_confirmation.confirmation")
      assert_selector "#school-preview", text: "Lycée Classique d'Abidjan"
    end
    assert_field "teacher_registration[last_name]", with: "Kouassi"
    assert_equal 0, Orm::User.count

    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_classrooms_path
    teacher = Orm::User.find_by!(contact: "0501020304", role: "teacher")
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher:).pluck(:school_id)
  end

  test "CE-02: the link shows the school and its DRENA, and the sign-up attaches the teacher to it" do
    visit school_code_signup_path("k7m4qz")

    within "#school-preview" do
      assert_text "Lycée Classique d'Abidjan"
      assert_text "Abidjan 1"
    end
    assert_no_field "teacher_registration[school_code]"
    fill_registration
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_classrooms_path
    assert_equal [ @school.id ], Orm::TeacherSchool.where(teacher: Orm::User.find_by!(contact: "0501020304")).pluck(:school_id)
  end

  test "CE-03: a wrong link says the code is invalid and leads to the field" do
    visit school_code_signup_path("abc234")

    assert_selector "#invalid-school-code", text: I18n.t("identity.teacher_registrations.new.invalid_code.title")
    assert_no_text "Lycée fermé"
    click_on I18n.t("identity.teacher_registrations.new.invalid_code.other_code")

    assert_current_path new_teacher_registration_path
    assert_field "teacher_registration[school_code]"
  end

  test "the same sign-up by the link on a 390 px screen" do
    with_mobile_viewport do
      visit school_code_signup_path("k7m4qz")

      assert_selector "#school-preview", text: "Lycée Classique d'Abidjan"
      assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"),
             "la page déborde en largeur"
      assert_no_page_reload do
        fill_registration(pin_confirmation: "1357")
        click_on I18n.t("#{FORM}.submit")

        assert_selector "#teacher_registration_pin_confirmation_error"
        assert_selector "#school-preview", text: "Lycée Classique d'Abidjan"
      end
      fill_in "teacher_registration[pin]", with: "4821"
      fill_in "teacher_registration[pin_confirmation]", with: "4821"
      click_on I18n.t("#{FORM}.submit")

      assert_toast I18n.t("identity.teacher_registrations.create.welcome")
      assert_current_path teacher_classrooms_path
    end
  end

  private

  # school_code: nil when the page came from a link (the code travels hidden).
  def fill_registration(school_code: nil, pin_confirmation: "4821")
    fill_in "teacher_registration[last_name]", with: "Kouassi"
    fill_in "teacher_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "teacher_registration[contact]", with: "05 01 02 03 04"
    fill_in "teacher_registration[school_code]", with: school_code if school_code
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: pin_confirmation
  end
end
