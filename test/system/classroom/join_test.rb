require "application_system_test_case"

# ID-01, ID-02, CL-06, CL-07 (UDR-0009): a visitor types the class code any way, sees the classroom, meets the 422 of
# an unconfirmed PIN without reloading the page, then signs up and lands home, signed in — on a desktop and at 390 px.
# /join sends a well-formed code by itself (FU-44, UDR-0054 §3.6): no click on « Continuer ».
# UDR-0009, amendment of 2026-10-02 (UDR-0057): at 390 px, both screens pass the sobriety rule; the help texts are info
# tips, and each state of /c/<code> keeps a single primary action.
class Classroom::JoinTest < ApplicationSystemTestCase
  # The student home belongs to Lot A2: until it is merged, a stand-in answers on its route, as in
  # test/system/identity/sign_in_test.rb. A merged controller is autoloadable, so the stand-in steps aside by itself.
  HOME = "Classroom::StudentHomesController".freeze

  unless Object.const_defined?(HOME)
    namespace = Object.const_defined?(:Classroom) ? Object.const_get(:Classroom) : Object.const_set(:Classroom, Module.new)
    namespace.const_set(:StudentHomesController, Class.new(AuthenticatedController) { def show = render(html: "accueil", layout: true) })
  end

  FORM = "classroom.joins.signup_form".freeze
  CODES = "classroom.join_codes.new".freeze
  JOINS = "classroom.joins.new".freeze
  INPUT = Dtos::Classroom::JoinWithCodeInput
  # Above the fold: on /join the logo and the card; on /c/<code> the left column (hidden under md), the logo and the card.
  JOIN_CODE_BLOCKS = "main > div > *".freeze
  JOIN_BLOCKS = "main > section:first-child, main > section:last-child > *".freeze
  ERRORS = "activemodel.errors.models.dtos/classroom/join_with_code_input.attributes".freeze

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    create_classroom(school:, level: create_level(name: "6ème"), name: "6ème 1", join_code: "kfm37")
  end

  test "a code typed any way, the preview, an unconfirmed PIN shown without reloading, then the arrival home" do
    visit new_join_code_path
    # FU-44 (UDR-0054 §3.6): the fifth valid character sends the code, without a click.
    fill_in "join[code]", with: "Kfm 37"

    assert_current_path join_classroom_path("kfm37")
    assert_selector "#classroom-preview", text: "6ème 1 — Lycée Classique d'Abidjan"

    sign_up_after_a_wrong_confirmation
  end

  test "the same journey on a 390 px screen, from /join to home, each screen sober" do
    with_mobile_viewport do
      visit new_join_code_path

      assert_sober JOIN_CODE_BLOCKS
      assert_no_text "Saisis le code de ta classe"
      assert_selector "#join_code_hint", exact_text: I18n.t("shared.autosubmit.hint_join")
      assert_info_tip I18n.t("#{CODES}.code_label"), I18n.t("#{CODES}.code_info_tip")
      fill_in "join[code]", with: "Kfm 37"

      assert_current_path join_classroom_path("kfm37")
      assert_selector "#classroom-preview", text: "6ème 1 — Lycée Classique d'Abidjan"
      assert_sober JOIN_BLOCKS
      assert_no_text "Tu rejoins cette classe"
      assert_no_selector "#join_contact_hint, #join_pin_hint"
      assert_selector "summary", text: tip_label(INPUT.human_attribute_name(:contact)), visible: :all
      assert_info_tip INPUT.human_attribute_name(:pin), I18n.t("#{FORM}.pin_info_tip")
      sign_up_after_a_wrong_confirmation
    end
  end

  test "at 390 px, a signed-in student sees the preview and one button, the reassurance in an info tip" do
    sign_in_as create_student(classroom: create_classroom)

    with_mobile_viewport do
      visit join_classroom_path("kfm37")

      assert_selector "h1", text: I18n.t("#{JOINS}.student_title")
      assert_sober JOIN_BLOCKS
      assert_button I18n.t("#{JOINS}.join_as_student")
      assert_info_tip I18n.t("#{JOINS}.student_title"), I18n.t("#{JOINS}.student_info_tip")
    end
  end

  test "an unknown code offers to type another one" do
    visit join_classroom_path("zzz99")

    assert_text I18n.t("classroom.joins.new.invalid_code.title")
    with_mobile_viewport { assert_sober JOIN_BLOCKS }
    click_on I18n.t("classroom.joins.new.invalid_code.other_code")

    assert_current_path new_join_code_path
  end

  test "D1: a well-formed but unknown code, typed on /join, is refused in the field, on a desktop and at 390 px" do
    [ nil, MOBILE_VIEWPORT ].each do |size|
      size ? with_mobile_viewport(size) { refuse_an_unknown_code } : refuse_an_unknown_code
    end
  end

  private

  def tip_label(label) = I18n.t("components.info_tip.label", label:)

  # UDR-0057 R1 and R2 on a public screen: its main has no id.
  def assert_sober(blocks)
    assert_blocks_above_fold blocks, max: 5
    assert_single_primary_action scope: "main"
  end

  # The help is hidden until the info tip is tapped.
  def assert_info_tip(label, text)
    assert_no_text text
    find("summary", text: tip_label(label), visible: :all).click
    assert_text text
  end

  def refuse_an_unknown_code
    visit new_join_code_path
    fill_in "join[code]", with: "ZZZ99"

    assert_selector "#join_code_error", text: I18n.t("classroom.joins.new.invalid_code.title")
    assert_current_path new_join_code_path
    assert_field "join[code]", with: "ZZZ99"
  end

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
