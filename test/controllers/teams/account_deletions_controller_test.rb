require "test_helper"

# ADR-0036 §4, lot R of fonctions-espace-eleve: a student or a parent asks the support to delete the account; a team member
# admin (ADR-0038) handles it from the account lookup, in a modal, with the date of the request. The account is anonymized, never deleted:
# its results stay, without its name.
class Teams::AccountDeletionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @actor = create_team_member(team_role: "admin")
    @student = create_student(classroom: create_classroom(name: "3ème 4"), contact: "0511223344", first_name: "Awa",
                              last_name: "Koné")
    @session = create_exercise_session(student: @student, status: "completed", score_percent: 80)
    create_login_session(user: @student)
    create_pin_recovery_code(user: @student)
    Orm::LoginAttempt.create!(contact: "0511223344", user_id: @student.id, succeeded: false, kind: "pin",
                              ip_address: "198.51.100.7", created_at: 1.day.ago)
  end

  def request_deletion(user = @student, requested_on: Date.current.iso8601, **options)
    post teams_account_deletion_path(user.public_id), params: { account_deletion: { requested_on: } }, **options
  end

  test "the modal names the student, says what is erased and what stays, and asks for the date of the request" do
    sign_in_as @actor

    get new_teams_account_deletion_path(@student.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#account-deletion-modal[open]" do
      assert_select "h2", "Supprimer le compte de Awa Koné ?"
      assert_select "p", text: /Le nom, le numéro, le PIN et la photo sont effacés/
      assert_select "p", text: /restent dans les chiffres de ses classes, sans son nom/
      assert_select "form#account-deletion-form[action='#{teams_account_deletion_path(@student.public_id)}'][method=post]" do
        assert_select "input[type=date][name='account_deletion[requested_on]'][required][max='#{Date.current.iso8601}']"
      end
      assert_select "button[type=submit][form=account-deletion-form]", text: "Supprimer le compte"
    end
  end

  test "the account is anonymized: toast, the result replaced, signed out, the results kept, the request in the journal" do
    sign_in_as @actor

    request_deletion requested_on: 3.days.ago.to_date.iso8601, as: :turbo_stream

    assert_response :success
    @student.reload
    assert_equal [ "Compte", "supprimé", nil ], [ @student.first_name, @student.last_name, @student.contact ]
    assert_not_nil @student.anonymized_at
    assert_not @student.authenticate_pin("2468")
    assert_not Orm::Session.exists?(user_id: @student.id)
    assert_not Orm::PinRecoveryCode.exists?(user_id: @student.id)
    assert_not Orm::LoginAttempt.where(user_id: @student.id).or(Orm::LoginAttempt.where(contact: "0511223344")).exists?
    assert_not_nil Orm::ClassroomStudent.find_by!(student: @student).left_at
    assert Orm::ExerciseSession.exists?(@session.id)
    event = Orm::AuditEvent.find_by!(action: "user.anonymized")
    assert_equal [ @actor.id, "User", @student.id, { "requested_on" => 3.days.ago.to_date.iso8601 } ],
                 [ event.actor_id, event.subject_type, event.subject_id, event.metadata ]
    assert_select "turbo-stream[action=append][target=toasts] template", text: /Compte de Awa Koné supprimé/
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=replace][target=account-lookup-result] template", text: /Compte supprimé/
  end

  test "the student can no longer sign in with the old number and PIN" do
    sign_in_as @actor
    request_deletion as: :turbo_stream
    sign_out

    post session_path, params: { session: { contact: "0511223344", pin: "2468" } }

    assert_response :unprocessable_entity
  end

  test "a missing or future date is refused in the modal, in 422, without change" do
    sign_in_as @actor

    request_deletion requested_on: "", headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#account_deletion_requested_on_error", "Saisissez la date à laquelle la demande a été reçue."

    request_deletion requested_on: Date.tomorrow.iso8601, headers: { "Turbo-Frame" => "modal" }
    assert_response :unprocessable_entity
    assert_select "#account_deletion_requested_on_error", "La date de la demande ne peut pas être dans le futur."

    assert_nil @student.reload.anonymized_at
    assert_not Orm::AuditEvent.exists?(action: "user.anonymized")
  end

  test "a student, a teacher and a school management are refused in 403, without change" do
    [ create_student, create_teacher, create_school_admin ].each do |user|
      sign_in_as user
      get new_teams_account_deletion_path(@student.public_id)
      assert_response :forbidden
      request_deletion
      assert_response :forbidden
      sign_out
    end

    assert_nil @student.reload.anonymized_at
  end

  # ADR-0038 : seul `admin` anonymise ; content et field n'ont pas le geste, ni dans la recherche.
  test "a team member content or field is refused in 403, and the lookup does not offer the deletion" do
    %w[content field].each do |team_role|
      sign_in_as create_team_member(team_role:)
      get new_teams_account_deletion_path(@student.public_id)
      assert_response :forbidden
      request_deletion
      assert_response :forbidden
      get teams_account_lookup_path(contact: @student.contact), headers: { "Turbo-Frame" => "account_lookup" }
      assert_select "#account-lookup-result"
      assert_select "a[href='#{new_teams_account_deletion_path(@student.public_id)}']", 0
      sign_out
    end

    assert_nil @student.reload.anonymized_at
  end

  # Le numéro libéré peut être repris : il ne doit pas hériter des échecs ni du verrou de l'ancien titulaire.
  test "the freed number inherits no failed attempt" do
    4.times { Orm::LoginAttempt.create!(contact: "0511223344", user_id: nil, succeeded: false, kind: "pin", created_at: 1.hour.ago) }
    sign_in_as @actor

    request_deletion as: :turbo_stream

    failures = Repositories::Identity::LoginAttemptRepository.new.consecutive_failures(contact: "0511223344", kind: "pin")
    assert_equal 0, failures.count
  end

  test "a teacher, a team member, an account already deleted or unknown has no request to handle here: 404" do
    gone = create_student(anonymized_at: 1.day.ago)
    sign_in_as @actor

    [ create_teacher, create_team_member(team_role: "content"), gone ].each do |user|
      get new_teams_account_deletion_path(user.public_id)
      assert_response :not_found
      request_deletion user
      assert_response :not_found
    end
    post teams_account_deletion_path("inconnu"), params: { account_deletion: { requested_on: Date.current.iso8601 } }
    assert_response :not_found
    assert_not Orm::AuditEvent.exists?(action: "user.anonymized")
  end

  test "without Turbo, back to the account lookup, with the notice" do
    sign_in_as @actor

    request_deletion

    assert_redirected_to teams_account_lookup_path
    assert_response :see_other
    assert_equal "Compte supprimé.", flash[:notice]
  end

  test "the account lookup offers the deletion for a student only" do
    sign_in_as @actor

    get teams_account_lookup_path(contact: @student.contact), headers: { "Turbo-Frame" => "account_lookup" }
    assert_select "a[href='#{new_teams_account_deletion_path(@student.public_id)}'][data-turbo-frame=modal]", "Supprimer le compte"

    teacher = create_teacher
    get teams_account_lookup_path(contact: teacher.contact), headers: { "Turbo-Frame" => "account_lookup" }
    assert_select "#account-lookup-result"
    assert_select "a[href='#{new_teams_account_deletion_path(teacher.public_id)}']", 0
  end
end
