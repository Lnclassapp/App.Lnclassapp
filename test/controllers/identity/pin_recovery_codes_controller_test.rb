require "test_helper"

# ID-15, ADR-0032, UDR-0020: a teacher for a student of their active classroom, the team for any other account; the
# code shows once, in the modal, never in the flash nor in the journal.
class Identity::PinRecoveryCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    @student = create_student(classroom: @classroom, first_name: "Awa", last_name: "Koné")
  end

  def issue_code(user, **options) = post account_pin_recovery_codes_path(user.public_id), **options

  test "a teacher issues a code for a student of their classroom: the code opens in the modal, only its digest is kept" do
    sign_in_as @teacher

    issue_code @student, as: :turbo_stream

    assert_response :success
    assert_secret_response(stream: true)
    recovery = Orm::PinRecoveryCode.sole
    assert_equal [ @student.id, @teacher.id ], [ recovery.user_id, recovery.issued_by_id ]
    assert_in_delta 15.minutes.from_now, recovery.expires_at, 5.seconds
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Code de récupération généré/
    assert_select "turbo-stream[action=update][target=modal] template" do
      assert_select "dialog#pin-recovery-code-modal"
      assert_select "p", text: "Pour Awa Koné"
      code = css_select("#pin-recovery-code").sole.text
      assert_match(/\A\d{4} \d{4}\z/, code)
      assert_equal secret_digest(code.delete(" ")), recovery.code_digest
      assert_select "#pin-recovery-code-expiry", text: "Valable jusqu'à #{I18n.l(recovery.expires_at, format: :hour_minute)}."
    end
    assert_equal 1, Orm::AuditEvent.where(action: "pin.recovery_code_issued", actor_id: @teacher.id, subject_id: @student.id).count
  end

  test "the code appears neither in the flash nor in the journal" do
    sign_in_as @teacher

    log = capture_log { issue_code @student, as: :turbo_stream }

    code = css_select("#pin-recovery-code").sole.text.delete(" ")
    assert_no_code_in_flash code
    assert_includes log, "Identity::PinRecoveryCodesController#create"
    assert_not_includes log, code
    assert_not_includes Orm::AuditEvent.pluck(:metadata).to_s, code
  end

  test "a teacher is refused for a student of another classroom, and a student is refused" do
    other = create_student(classroom: create_classroom)
    sign_in_as @teacher

    issue_code other, as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Accès interdit/
    sign_out

    sign_in_as create_student(classroom: @classroom)
    issue_code @student, as: :turbo_stream
    assert_response :forbidden
    assert_not Orm::PinRecoveryCode.exists?
  end

  test "the team issues a code for any account but its own" do
    member = create_team_member
    sign_in_as member

    issue_code @teacher, as: :turbo_stream
    assert_response :success

    issue_code member, as: :turbo_stream
    assert_response :forbidden
    assert_equal [ @teacher.id ], Orm::PinRecoveryCode.pluck(:user_id)
  end

  test "an unknown account gives 404 and a visitor is sent to the sign-in" do
    post account_pin_recovery_codes_path("inconnu")
    assert_redirected_to new_session_path

    sign_in_as @teacher
    post account_pin_recovery_codes_path("inconnu")
    assert_response :not_found
  end

  test "without Turbo, the code is rendered in the page, never in a flash" do
    sign_in_as @teacher

    issue_code @student

    assert_response :created
    assert_secret_response
    assert_select "main#main turbo-frame#modal dialog#pin-recovery-code-modal #pin-recovery-code"
    assert_no_code_in_flash css_select("#pin-recovery-code").sole.text.delete(" ")
  end

  test "an eleventh code in a minute is refused in 429, by toast or in the page" do
    sign_in_as @teacher

    10.times { issue_code @student, as: :turbo_stream }
    issue_code @student, as: :turbo_stream
    assert_response :too_many_requests
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Trop de tentatives en une minute/

    issue_code @student
    assert_response :too_many_requests
    assert_equal I18n.t("errors.codes.rate_limited"), response.body
    assert_equal 1, Orm::PinRecoveryCode.where(used_at: nil, revoked_at: nil).count
  end

  private

  def assert_no_code_in_flash(code)
    assert(flash.to_h.values.none? { it.to_s.include?(code) }, "le code ne doit jamais passer par le flash")
  end

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end
