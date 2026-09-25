require "test_helper"

# ID-02, CL-07 (UDR-0009): « Rejoindre une classe » takes a code typed any way and opens /c/<code>, without looking it up.
class Classroom::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  test "the screen asks for the class code, for a visitor" do
    get new_join_code_path

    assert_response :success
    assert_select "form#join-code-form[action='#{join_codes_path}'][method=post]"
    assert_select "input[name='join[code]'][autocomplete=off][autocapitalize=characters][maxlength]"
    assert_select "label", text: /#{I18n.t('classroom.join_codes.new.code_label')}/
  end

  test "a code typed with capitals and spaces opens its normalized page" do
    post join_codes_path, params: { join: { code: " Kfm 37 " } }

    assert_redirected_to join_classroom_path("kfm37")
    assert_response :see_other
  end

  test "the code is not looked up here: an unknown well-formed code still opens its page" do
    post join_codes_path, params: { join: { code: "zzz99" } }

    assert_redirected_to join_classroom_path("zzz99")
  end

  test "a blank code is refused in 422 with its message" do
    post join_codes_path, params: { join: { code: "  " } }

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t("classroom.join_codes.create.blank")
  end

  test "a malformed code is refused in 422, the entry is kept" do
    post join_codes_path, params: { join: { code: "ab/12" } }

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t("classroom.join_codes.create.invalid")
    assert_select "input[name='join[code]'][value='ab/12'][aria-invalid=true]"
  end

  test "without the join parameter, the code is blank" do
    post join_codes_path

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t("classroom.join_codes.create.blank")
  end

  test "a signed-in student reaches the screen too, to change class" do
    sign_in_as create_student

    get new_join_code_path

    assert_response :success
  end
end
