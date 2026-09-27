require "application_system_test_case"

# ID-01, ID-02, CL-06, CL-07 (UDR-0009): a visitor types the class code any way, sees the classroom, meets the 422 of
# an unconfirmed PIN without reloading the page, then signs up and lands home, signed in — on a desktop and at 390 px.
class Classroom::JoinTest < ApplicationSystemTestCase
  # The student home belongs to Lot A2: until it is merged, a stand-in answers on its route, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  HOME = "Classroom::StudentHomesController".freeze

  unless Object.const_defined?(HOME)
    namespace = Object.const_defined?(:Classroom) ? Object.const_get(:Classroom) : Object.const_set(:Classroom, Module.new)
    namespace.const_set(:StudentHomesController, Class.new(AuthenticatedController) { def show = render(html: "accueil", layout: true) })
  end

  FORM = "classroom.joins.signup_form".freeze
  ERRORS = "activemodel.errors.models.dtos/classroom/join_with_code_input.attributes".freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    create_classroom(school:, level: create_level(name: "6ème"), name: "6ème 1", join_code: "kfm37")
  end

  test "a code typed any way, the preview, an unconfirmed PIN shown without reloading, then the arrival home" do
    visit new_join_code_path
    fill_in "join[code]", with: "Kfm 37"
    click_on I18n.t("classroom.join_codes.new.submit")

    assert_current_path join_classroom_path("kfm37")
    assert_selector "#classroom-preview", text: "6ème 1 — Lycée Classique d'Abidjan"

    sign_up_after_a_wrong_confirmation
  end

  test "the same journey on a 390 px screen" do
    with_mobile_viewport do
      visit join_classroom_path("KFM37")

      assert_selector "#classroom-preview", text: "6ème 1 — Lycée Classique d'Abidjan"
      sign_up_after_a_wrong_confirmation
    end
  end

  test "an unknown code offers to type another one" do
    visit join_classroom_path("zzz99")

    assert_text I18n.t("classroom.joins.new.invalid_code.title")
    click_on I18n.t("classroom.joins.new.invalid_code.other_code")

    assert_current_path new_join_code_path
  end

  private

  def sign_up_after_a_wrong_confirmation
    assert_no_page_reload do
      fill_in "join[last_name]", with: "Kouassi"
      fill_in "join[first_name]", with: "Aya Marie"
      choose I18n.t("genders.female")
      fill_in "join[contact]", with: "07 01 02 03 04"
      fill_in "join[pin]", with: "4821"
      fill_in "join[pin_confirmation]", with: "1357"
      click_on I18n.t("#{FORM}.submit")

      assert_selector "#join_pin_confirmation_error", text: I18n.t("#{ERRORS}.pin_confirmation.confirmation")
    end
    assert_field "join[last_name]", with: "Kouassi"
    assert_equal 0, Orm::User.count

    fill_in "join[pin]", with: "4821"
    fill_in "join[pin_confirmation]", with: "4821"
    click_on I18n.t("#{FORM}.submit")

    assert_toast I18n.t("classroom.joins.create.welcome")
    assert_current_path student_home_path
    assert Orm::User.exists?(contact: "0701020304", role: "student")
  end
end
