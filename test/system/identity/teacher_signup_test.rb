require "application_system_test_case"

# ID-03, ID-08, SC-27 (UDR-0024): a visitor picks a DRENA and its schools appear in the « schools » frame, meets the
# 422 of an unconfirmed PIN, then signs up and lands on the class selection — all without reloading the page until
# the account exists.
class Identity::TeacherSignupTest < ApplicationSystemTestCase
  # The class selection belongs to Lot D2: until it is merged, a stand-in answers on its route, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  SELECTION = "Classroom::TeachingSelectionsController".freeze

  unless Object.const_defined?(SELECTION)
    namespace = Object.const_defined?(:Classroom) ? Object.const_get(:Classroom) : Object.const_set(:Classroom, Module.new)
    namespace.const_set(:TeachingSelectionsController, Class.new(AuthenticatedController) { def index = render(html: "classes", layout: true) })
  end

  FORM = "identity.teacher_registrations.form".freeze

  setup do
    @abidjan1 = create_drena(name: "Abidjan 1")
    @abidjan2 = create_drena(name: "Abidjan 2")
    create_school(drena: @abidjan1, name: "Lycée Classique d'Abidjan")
    create_school(drena: @abidjan1, name: "Collège Voltaire")
    create_school(drena: @abidjan1, name: "Lycée fermé", status: "inactive")
    create_school(drena: @abidjan2, name: "Lycée moderne de Cocody")
    create_material(name: "SVT", shortname: "SVT")
  end

  test "choosing a DRENA lists its active schools without reloading the page" do
    visit new_teacher_registration_path

    assert_no_button I18n.t("#{FORM}.show_schools")
    assert_selector "turbo-frame#schools select[disabled]"
    assert_no_page_reload do
      select "Abidjan 1", from: "teacher_registration[drena_public_id]"

      assert_selector "turbo-frame#schools select:not([disabled])"
      assert_equal [ "Collège Voltaire", "Lycée Classique d'Abidjan" ], school_names

      select "Abidjan 2", from: "teacher_registration[drena_public_id]"

      assert_selector "turbo-frame#schools option", text: "Lycée moderne de Cocody"
      assert_equal [ "Lycée moderne de Cocody" ], school_names
    end
  end

  test "an unconfirmed PIN shows its error without reloading the page, then the right sign-up lands on the class selection" do
    visit new_teacher_registration_path

    assert_no_page_reload do
      fill_registration(pin_confirmation: "1357")
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#teacher_registration_pin_confirmation_error",
                      text: I18n.t("activemodel.errors.models.dtos/identity/teacher_registration_input.attributes.pin_confirmation.confirmation")
    end
    assert_no_button I18n.t("#{FORM}.show_schools")
    assert_field "teacher_registration[last_name]", with: "Kouassi"
    assert_select "teacher_registration[school_public_id]", selected: "Lycée Classique d'Abidjan"
    assert_equal 0, Orm::User.count

    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("identity.teacher_registrations.create.welcome")
    assert_current_path teacher_classrooms_path
    assert Orm::User.exists?(contact: "0501020304", role: "teacher")
  end

  test "the same sign-up on a 390 px screen" do
    with_mobile_viewport do
      visit new_teacher_registration_path

      assert_no_page_reload do
        fill_registration(pin_confirmation: "1357")
        click_on I18n.t("#{FORM}.submit")

        assert_selector "#teacher_registration_pin_confirmation_error"
      end
      fill_in "teacher_registration[pin]", with: "4821"
      fill_in "teacher_registration[pin_confirmation]", with: "4821"
      click_on I18n.t("#{FORM}.submit")

      assert_toast I18n.t("identity.teacher_registrations.create.welcome")
      assert_current_path teacher_classrooms_path
    end
  end

  private

  def school_names = all("turbo-frame#schools option:not([value=''])").map(&:text)

  def fill_registration(pin_confirmation:)
    fill_in "teacher_registration[last_name]", with: "Kouassi"
    fill_in "teacher_registration[first_name]", with: "Aya Marie"
    choose I18n.t("genders.female")
    fill_in "teacher_registration[contact]", with: "05 01 02 03 04"
    select "Abidjan 1", from: "teacher_registration[drena_public_id]"
    select "Lycée Classique d'Abidjan", from: "teacher_registration[school_public_id]"
    select "SVT", from: "teacher_registration[material_slug]"
    fill_in "teacher_registration[pin]", with: "4821"
    fill_in "teacher_registration[pin_confirmation]", with: pin_confirmation
  end
end
