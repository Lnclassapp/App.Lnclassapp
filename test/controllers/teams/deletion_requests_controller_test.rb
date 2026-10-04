require "test_helper"

# ADR-0036, amendment (2), lot R3 of fonctions-espace-eleve: the team `admin` (ADR-0038) records a deletion request when
# the support receives it, sees it on the account until it is processed, cancels it if the student takes it back, and
# reads the pending requests by due date (reception + 30 days): amber from the 25th day, « En retard » from the 31st.
class Teams::DeletionRequestsControllerTest < ActionDispatch::IntegrationTest
  TODAY = Date.new(2026, 10, 2)

  setup do
    travel_to Time.zone.local(2026, 10, 2, 10)
    @admin = create_team_member(team_role: "admin")
    @student = create_student(contact: "0511223344", first_name: "Awa", last_name: "Koné")
  end

  def t(key, **) = I18n.t("teams.deletion_requests.#{key}", **)
  def date(value) = I18n.l(value, format: :due_short)
  def block = { "Turbo-Frame" => Teams::DeletionRequestsController::BLOCK_FRAME }

  def request_for(student, requested_on)
    Orm::AccountDeletionRequest.create!(user: student, requested_on:, recorded_by: @admin)
  end

  def record_request(user = @student, requested_on: "2026-09-28", **options)
    post teams_deletion_request_path(user.public_id), params: { deletion_request: { requested_on: } }, **options
  end

  test "without request, the account offers to record one, in the modal" do
    sign_in_as @admin

    get teams_deletion_request_path(@student.public_id), headers: block

    assert_response :success
    assert_select "turbo-frame##{Teams::DeletionRequestsController::BLOCK_FRAME}" do
      assert_select "a[href='#{new_teams_deletion_request_path(@student.public_id)}'][data-turbo-frame=modal]",
                    t("account_block.record")
      assert_select "form#deletion-request-cancel-form", 0
    end
  end

  test "the modal asks for the date of reception, never in the future" do
    sign_in_as @admin

    get new_teams_deletion_request_path(@student.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#deletion-request-modal[open]" do
      assert_select "h2", t("new.title", name: "Awa Koné")
      assert_select "form#deletion-request-form[action='#{teams_deletion_request_path(@student.public_id)}'][method=post]" do
        assert_select "input[type=date][name='deletion_request[requested_on]'][required][max='2026-10-02']"
      end
      assert_select "button[type=submit][form=deletion-request-form]", t("new.submit")
    end
  end

  test "the request is recorded: toast, modal closed, « Demande reçue le … » on the account, in the journal" do
    sign_in_as @admin

    record_request as: :turbo_stream

    assert_response :success
    request = Orm::AccountDeletionRequest.sole
    assert_equal [ @student.id, Date.new(2026, 9, 28), @admin.id, "pending" ],
                 [ request.user_id, request.requested_on, request.recorded_by_id, request.status ]
    event = Orm::AuditEvent.find_by!(action: "user.deletion_requested")
    assert_equal [ @admin.id, @student.id, { "requested_on" => "2026-09-28" } ], [ event.actor_id, event.subject_id, event.metadata ]
    assert_select "turbo-stream[action=append][target=toasts] template", text: /#{t("create.done", name: "Awa Koné")}/
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=replace][target=#{Teams::DeletionRequestsController::BLOCK_FRAME}] template" do
      assert_select "p", t("account_block.received", date: date(Date.new(2026, 9, 28)))
      assert_select "span", t("due.before", date: date(Date.new(2026, 10, 28)))
      assert_select "form#deletion-request-cancel-form[action='#{teams_deletion_request_path(@student.public_id)}']"
    end
    assert_nil @student.reload.anonymized_at
  end

  test "a missing or future date is refused in the modal, in 422, without writing" do
    sign_in_as @admin

    record_request requested_on: "", headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#deletion_request_requested_on_error", "Saisissez la date à laquelle la demande a été reçue."

    record_request requested_on: "2026-10-03", headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#deletion_request_requested_on_error", "La date de la demande ne peut pas être dans le futur."

    assert_not Orm::AccountDeletionRequest.exists?
    assert_not Orm::AuditEvent.exists?(action: "user.deletion_requested")
  end

  test "a second request while one is pending is refused in the modal, in 422" do
    request_for(@student, Date.new(2026, 9, 1))
    sign_in_as @admin

    record_request headers: { "Turbo-Frame" => "modal" }

    assert_response :unprocessable_entity
    assert_select "#deletion-request-modal [role=alert]", text: /déjà en attente/
    assert_equal 1, Orm::AccountDeletionRequest.count
  end

  test "a pending request is shown on the account, then cancelled: the account offers to record one again" do
    request_for(@student, Date.new(2026, 9, 6))
    sign_in_as @admin

    get teams_deletion_request_path(@student.public_id), headers: block
    assert_select "#account-deletion-request-pending" do
      assert_select "p", t("account_block.received", date: date(Date.new(2026, 9, 6)))
      assert_select "span.bg-warning-soft", t("due.before", date: date(Date.new(2026, 10, 6)))
    end

    delete teams_deletion_request_path(@student.public_id), as: :turbo_stream

    assert_response :success
    request = Orm::AccountDeletionRequest.sole
    assert_equal [ "cancelled", @admin.id ], [ request.status, request.closed_by_id ]
    assert_not_nil request.closed_at
    assert_equal({ "requested_on" => "2026-09-06" }, Orm::AuditEvent.find_by!(action: "user.deletion_request_cancelled").metadata)
    assert_select "turbo-stream[action=append][target=toasts] template", text: /#{t("destroy.done", name: "Awa Koné")}/
    assert_select "turbo-stream[action=replace][target=#{Teams::DeletionRequestsController::BLOCK_FRAME}] template" do
      assert_select "a[href='#{new_teams_deletion_request_path(@student.public_id)}']", t("account_block.record")
    end
  end

  test "cancelling without a pending request is not found" do
    sign_in_as @admin

    delete teams_deletion_request_path(@student.public_id), as: :turbo_stream

    assert_response :not_found
    assert_not Orm::AuditEvent.exists?(action: "user.deletion_request_cancelled")
  end

  test "without Turbo, back to the account, with the notice" do
    sign_in_as @admin

    record_request
    assert_redirected_to teams_account_lookup_path(contact: "0511223344")
    assert_equal t("create.notice"), flash[:notice]

    delete teams_deletion_request_path(@student.public_id)
    assert_redirected_to teams_account_lookup_path(contact: "0511223344")
    assert_equal t("destroy.notice"), flash[:notice]
  end

  test "a teacher, a team member, an account already deleted or unknown has no deletion request: 404" do
    gone = create_student(anonymized_at: 1.day.ago)
    sign_in_as @admin

    [ create_teacher, create_team_member(team_role: "content"), gone ].each do |user|
      get teams_deletion_request_path(user.public_id), headers: block
      assert_response :not_found
      get new_teams_deletion_request_path(user.public_id)
      assert_response :not_found
      record_request user
      assert_response :not_found
      delete teams_deletion_request_path(user.public_id)
      assert_response :not_found
    end
    record_request Data.define(:public_id).new("inconnu")
    assert_response :not_found
    assert_not Orm::AccountDeletionRequest.exists?
  end

  test "every role but the team admin is refused in 403, without writing, and sees neither the block nor the list" do
    request_for(@student, Date.new(2026, 9, 6))
    [ create_team_member(team_role: "content"), create_team_member(team_role: "field"), create_student, create_teacher,
      create_school_admin ].each do |user|
      sign_in_as user
      get teams_deletion_requests_path
      assert_response :forbidden
      get teams_deletion_request_path(@student.public_id), headers: block
      assert_response :forbidden
      get new_teams_deletion_request_path(@student.public_id)
      assert_response :forbidden
      record_request create_student
      assert_response :forbidden
      delete teams_deletion_request_path(@student.public_id)
      assert_response :forbidden
      sign_out
    end

    assert_equal [ "pending" ], Orm::AccountDeletionRequest.pluck(:status)
    assert_not Orm::AuditEvent.where(action: %w[user.deletion_requested user.deletion_request_cancelled]).exists?
  end

  test "the list shows the pending requests, nearest due date first, each leading to the account" do
    yao = create_student(first_name: "Yao", last_name: "Brou", contact: "0100000002")
    request_for(@student, Date.new(2026, 9, 20))
    request_for(yao, Date.new(2026, 9, 1))
    sign_in_as @admin

    get teams_deletion_requests_path

    assert_response :success
    assert_select "h1", t("index.title")
    assert_select "#deletion_requests li", 2
    assert_select "#deletion_requests li:first-child##{"deletion_request_#{yao.public_id}"}" do
      assert_select "a[href=?]", teams_account_lookup_path(contact: "0100000002"), text: "Yao Brou"
      assert_select "p", t("index.received", date: date(Date.new(2026, 9, 1)))
      assert_select "span.bg-warning-soft", t("due.late", date: date(Date.new(2026, 10, 1)))
    end
    assert_select "#deletion_requests li:last-child" do
      assert_select "a[href=?]", teams_account_lookup_path(contact: "0511223344"), text: "Awa Koné"
      assert_select "span.bg-warning-soft", 0
      assert_select "span", t("due.before", date: date(Date.new(2026, 10, 20)))
    end
  end

  test "an empty list says what to expect" do
    sign_in_as @admin

    get teams_deletion_requests_path

    assert_select "#deletion_requests", 0
    assert_select "*", text: t("index.empty_title")
  end

  # UDR-0057 R3: three lines, then « Voir plus » reveals the next ones, already rendered.
  test "beyond three requests, the next ones are folded behind « Voir plus »" do
    4.times { |day| request_for(create_student, Date.new(2026, 9, 10 + day)) }
    sign_in_as @admin

    get teams_deletion_requests_path

    assert_select "#deletion_requests[data-controller=reveal] li[data-reveal-target=item]", 4
    assert_select "#deletion_requests li[hidden]", 1
    assert_select "#deletion_requests button[data-action='reveal#more']"
  end

  # The amber starts on the 25th day after the reception, « En retard » on the 31st.
  test "the due date turns amber on the 25th day and late on the 31st" do
    request_for(@student, Date.new(2026, 9, 1))
    sign_in_as @admin

    { 24 => [ "before", false ], 25 => [ "before", true ], 30 => [ "before", true ], 31 => [ "late", true ] }.each do |day, (key, amber)|
      travel_to Time.zone.local(2026, 9, 1, 10) + day.days do
        get teams_deletion_requests_path

        assert_select "#deletion_request_#{@student.public_id} span", t("due.#{key}", date: date(Date.new(2026, 10, 1)))
        assert_select "#deletion_request_#{@student.public_id} span.bg-warning-soft", amber ? 1 : 0
      end
    end
  end
end
