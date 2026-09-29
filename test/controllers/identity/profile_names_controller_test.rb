require "test_helper"

# PR-03, ADR-0055, UDR-0041: the name is corrected in the modal frame; the card is replaced in Turbo Stream, with a
# toast and an audit trace; the HTML fallback redirects to the profile; the sign-up limits give a 422 in the modal.
class Identity::ProfileNamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student = create_student(first_name: "Aya", last_name: "Koné")
  end

  def rename(first_name: "Aya Marie", last_name: "Koné", **options)
    patch profile_name_path, params: { profile_name: { first_name:, last_name: } }, **options
  end

  test "a visitor is sent to the sign-in, and nothing is written" do
    get edit_profile_name_path
    assert_redirected_to new_session_path
    rename

    assert_redirected_to new_session_path
    assert_equal "Aya", @student.reload.first_name
  end

  test "the form opens in the modal frame, filled with the current name" do
    sign_in_as @student

    get edit_profile_name_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#profile-name-modal[aria-labelledby]", text: /Modifier mon nom/
    assert_select "form#profile-name-form[action='#{profile_name_path}']" do
      assert_select "input[name=_method][value=patch]", visible: :all
      assert_select "input[name='profile_name[last_name]'][value='Koné'][maxlength='50'][autocomplete=family-name][required]"
      assert_select "input[name='profile_name[first_name]'][value='Aya'][maxlength='80'][autocomplete=given-name][required]"
    end
    assert_select "button[type=submit][form=profile-name-form]", "Enregistrer"
  end

  test "a valid name answers in Turbo Stream: card replaced, modal closed, toast; the change is audited" do
    sign_in_as @student

    rename(first_name: "  Aya   Marie ", as: :turbo_stream)

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /Votre nom est enregistré\./
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=replace][target=profile_information] template #profile_information dd", text: /Aya Marie Koné/
    assert_equal [ "Aya Marie", "Koné" ], [ @student.reload.first_name, @student.last_name ]
    event = Orm::AuditEvent.find_by!(action: "profile.name_changed")
    assert_equal [ @student.id, "User", @student.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "previous" => { "first_name" => "Aya", "last_name" => "Koné" },
                   "current" => { "first_name" => "Aya Marie", "last_name" => "Koné" } }, event.metadata)
  end

  test "without Turbo, a valid name redirects to the profile with the toast" do
    sign_in_as @student

    rename

    assert_redirected_to profile_path
    assert_response :see_other
    follow_redirect!
    assert_select "#toasts", text: /Votre nom est enregistré\./
    assert_select "#profile_information dd", text: /Aya Marie Koné/
  end

  test "an empty, blank or too long name is refused in 422 in the modal, and nothing is written" do
    sign_in_as @student

    [ { last_name: "", message: "Saisissez votre nom." }, { first_name: "   ", message: "Saisissez votre ou vos prénoms." },
      { last_name: "a" * 51, message: "Le nom compte 50 caractères au plus." },
      { first_name: "b" * 81, message: "Les prénoms comptent 80 caractères au plus." } ].each do |attributes|
      message = attributes.delete(:message)
      rename(**attributes, headers: { "Turbo-Frame" => "modal" })

      assert_response :unprocessable_entity
      assert_select "turbo-frame#modal form#profile-name-form"
      assert_select "p[id$=_error]", text: message
    end
    assert_select "input[name='profile_name[first_name]'][value='#{'b' * 81}'][aria-invalid=true]"
    assert_equal "Aya", @student.reload.first_name
    assert_not Orm::AuditEvent.exists?(action: "profile.name_changed")
  end
end
