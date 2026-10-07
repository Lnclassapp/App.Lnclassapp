require "test_helper"

# PH-01, PH-03, PH-04, PH-06, ADR-0060, UDR-0047: the photo is added, replaced and removed in the modal frame of
# « Mon profil »; success refreshes the page in Turbo Stream with a toast; the server refuses what is not a small image
# in 422 in the modal; no identifier is taken: always the account of the session.
class Identity::ProfilePhotosControllerTest < ActionDispatch::IntegrationTest
  TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  MODAL = { "Turbo-Frame" => "modal" }.freeze

  setup do
    @student = create_student(first_name: "Aya", last_name: "Koné")
  end

  def upload(name, type = "image/jpeg") = fixture_file_upload("photos/#{name}", type)

  def change(photo, headers: TURBO_STREAM, **params)
    patch profile_photo_path, params: { profile_photo: { photo: }.compact, **params }, headers:
  end

  def stored = Orm::User.find(@student.id).photo

  test "a visitor is sent to the sign-in, and nothing is written" do
    get edit_profile_photo_path
    assert_redirected_to new_session_path
    change(upload("photo.jpg"))
    assert_redirected_to new_session_path
    delete profile_photo_path

    assert_redirected_to new_session_path
    assert_not stored.attached?
  end

  test "the modal opens in the frame: current initials, an image field without capture, no removal without a photo" do
    sign_in_as @student

    get edit_profile_photo_path, headers: MODAL

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#profile-photo-modal[aria-labelledby]", text: /Ma photo/
    assert_select "[data-identity--photo-picker-target=current] [role=img][aria-label='Aya Koné'].size-28", text: "AK"
    assert_select "img[data-identity--photo-picker-target=preview][hidden][alt='Aperçu de ta nouvelle photo']"
    assert_select "form#profile-photo-form[action='#{profile_photo_path}'][enctype='multipart/form-data'][data-controller='identity--photo-picker']" do
      assert_select "input[name=_method][value=patch]", visible: :all
      assert_select "input[type=file][name='profile_photo[photo]'][accept='image/jpeg,image/png,image/webp,image/*']" \
                    "[required][aria-describedby=profile_photo_photo_hint]:not([capture])"
      assert_select "label[for=profile_photo_photo]", text: /Photo/
      assert_select "#profile_photo_photo_hint", text: /recadrée en carré et allégée sur ton téléphone/
    end
    assert_select "button[type=submit][form=profile-photo-form]", "Enregistrer"
    assert_select "form[action='#{profile_photo_path}'] input[name=_method][value=delete]", count: 0
  end

  test "with a photo, the modal shows it and offers to remove it" do
    attach_photo(@student)
    sign_in_as @student

    get edit_profile_photo_path, headers: MODAL

    version = Queries::Identity::PhotoVersions.for(user_ids: [ @student.id ])[@student.id]
    assert_select "[data-identity--photo-picker-target=current] img[src='#{account_photo_path(@student.public_id, v: version)}']"
    assert_select "form[action='#{profile_photo_path}'] input[name=_method][value=delete]", visible: :all
    assert_select "form[action='#{profile_photo_path}'] button", text: /Retirer ma photo/
  end

  test "a valid photo answers in Turbo Stream: toast, modal emptied, page refreshed; stored without Exif and audited" do
    sign_in_as @student

    change(upload("photo_exif.jpg"))

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /Ta photo est enregistrée\./
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
    assert_equal "image/jpeg", stored.content_type
    assert_not Entities::Shared::ImageHeader.read(stored.download).metadata
    event = Orm::AuditEvent.find_by!(action: "profile.photo_changed")
    assert_equal [ @student.id, "User", @student.id ], [ event.actor_id, event.subject_type, event.subject_id ]
    assert_equal({ "content_type" => "image/jpeg", "byte_size" => stored.byte_size, "width" => 64, "height" => 48,
                   "replaced" => false }, event.metadata)
  end

  # Challenge of PR #65, M4: a smartphone JPEG (Motion Photo, MPF, gain map) is accepted, cut at its first EOI.
  test "a JPEG with a secondary image and a secret after its EOI is stored without them" do
    sign_in_as @student

    change(upload("hostile/motion_photo_trailer.jpg"))

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /Ta photo est enregistrée\./
    assert_equal file_fixture("photos/photo.jpg").binread, stored.download
  end

  test "without Turbo, a valid photo redirects to the profile with the toast, and the profile shows it" do
    sign_in_as @student

    change(upload("photo_lossy.webp", "image/webp"), headers: {})

    assert_redirected_to profile_path
    assert_response :see_other
    follow_redirect!
    assert_select "#toasts", text: /Ta photo est enregistrée\./
    assert_select "#profile_information img[alt='Aya Koné'][src^='#{account_photo_path(@student.public_id)}?v=']"
  end

  test "no file, a PDF, a too heavy or a too wide image: 422 in the modal, message under the field, nothing stored" do
    sign_in_as @student
    heavy = Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8".b + ("\0" * 1_048_577)), "image/jpeg", original_filename: "lourde.jpg")

    [ [ nil, "Aucune photo n'est choisie." ], [ upload("document.pdf", "image/jpeg"), "La photo est en JPEG, PNG ou WebP." ],
      [ heavy, "La photo pèse 1 Mo au plus." ], [ upload("too_wide.png", "image/png"), "La photo mesure 1024 pixels de côté au plus." ] ]
      .each do |photo, message|
        change(photo, headers: MODAL)

        assert_response :unprocessable_entity
        assert_select "turbo-frame#modal form#profile-photo-form"
        assert_select "#profile_photo_photo_error", text: message
        assert_select "input[type=file][aria-invalid=true][aria-describedby='profile_photo_photo_hint profile_photo_photo_error']"
      end
    assert_not stored.attached?
    assert_not Orm::AuditEvent.exists?(action: "profile.photo_changed")
  end

  test "removing answers in Turbo Stream, erases the file and audits; the HTML fallback redirects" do
    attach_photo(@student)
    key = stored.blob.key
    sign_in_as @student

    delete profile_photo_path, headers: TURBO_STREAM

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /Ta photo est retirée\./
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
    assert_not stored.attached?
    assert_not ActiveStorage::Blob.service.exist?(key)
    assert Orm::AuditEvent.exists?(action: "profile.photo_removed", actor_id: @student.id)

    delete profile_photo_path

    assert_redirected_to profile_path
    assert_equal 1, Orm::AuditEvent.where(action: "profile.photo_removed").count
  end

  test "the actions take no identifier: always the account of the session" do
    other = create_student
    attach_photo(other)
    sign_in_as @student

    change(upload("photo.png", "image/png"), user_id: other.id, user_public_id: other.public_id)
    delete profile_photo_path(user_id: other.id)

    assert_not stored.attached?
    assert Orm::User.find(other.id).photo.attached?
    assert_equal "image/jpeg", Orm::User.find(other.id).photo.content_type
  end

  # Challenge of PR #50: files posted directly, without the browser's crop.
  test "a direct post of a truncated, corrupt or stray-byte image is refused; fill bytes cannot smuggle Exif in" do
    sign_in_as @student

    { "truncated.webp" => "image/webp", "bomb_header.webp" => "image/webp", "corrupt.webp" => "image/webp",
      "bypass_exif.jpg" => "image/jpeg" }.each do |name, type|
      change(upload("hostile/#{name}", type), headers: MODAL)

      assert_response :unprocessable_entity, name
      assert_select "#profile_photo_photo_error", text: "La photo est en JPEG, PNG ou WebP."
    end
    assert_not stored.attached?

    change(upload("hostile/bypass_fill.jpg"))

    assert_response :success
    assert_not_includes stored.download, "Exif"
    assert_not_includes stored.download, "SECRETCAM"
  end
end
