require "test_helper"

# ID-02, ID-07, CL-07 (ADR-0041, UDR-0009): « Rejoindre une classe » takes a code typed any way and opens /c/<code> only
# when that page has a preview; otherwise the code is refused in its field, in 422, saying no more than /c/<code>.
# The check shares the rate limit of /c/<code> (recette-v1-defauts, D1).
class Classroom::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  UNKNOWN = "classroom.join_codes.create.unknown".freeze

  setup { @classroom = create_classroom(name: "6ème 1", join_code: "kfm37") }

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

  test "D1: an unknown well-formed code is refused in 422, in its field, with the words of /c/<code> and nothing more" do
    post join_codes_path, params: { join: { code: "ZZZ99" } }

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t(UNKNOWN)
    assert_includes I18n.t(UNKNOWN), I18n.t("classroom.joins.new.invalid_code.title")
    assert_select "input[name='join[code]'][value='ZZZ99'][aria-invalid=true]"
  end

  test "D1: the code of an archived classroom, closed at the archiving, is refused like an unknown one" do
    @classroom.update!(status: "archived", archived_at: Time.current, join_code: nil)

    post join_codes_path, params: { join: { code: "kfm37" } }

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t(UNKNOWN)
  end

  test "D1: a replaced code is refused like an unknown one" do
    @classroom.update!(join_code: "kfm38")

    post join_codes_path, params: { join: { code: "kfm37" } }

    assert_response :unprocessable_entity
    assert_select "#join_code_error", text: I18n.t(UNKNOWN)
  end

  test "D1: the eleventh check in a minute from the same address receives 429, without looking the code up" do
    10.times { post join_codes_path, params: { join: { code: "zzz99" } } }

    post join_codes_path, params: { join: { code: "kfm37" } }

    assert_response :too_many_requests
    assert_select "#join_code_error", text: I18n.t("classroom.join_codes.create.rate_limited")
  end

  test "D1: the check and /c/<code> share one counter" do
    5.times { post join_codes_path, params: { join: { code: "zzz99" } } }
    5.times { get join_classroom_path("zzz99") }

    post join_codes_path, params: { join: { code: "kfm37" } }

    assert_response :too_many_requests
  end

  test "the screen itself is not rate limited" do
    11.times { get new_join_code_path }

    assert_response :success
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
