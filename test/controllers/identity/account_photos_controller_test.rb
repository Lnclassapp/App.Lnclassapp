require "test_helper"

# PH-05, ADR-0060: a photo is served only under a session and ReadUserPolicy — the account itself, the team, a teacher
# of the student's classroom — as a private, versioned, inline image; never by an Active Storage address.
class Identity::AccountPhotosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom
    @teacher = create_teacher(classrooms: [ @classroom ])
    @student = attach_photo(create_student(classroom: @classroom))
  end

  def photo_of(user) = get(account_photo_path(user.public_id, v: "any"))

  def assert_photo_served
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal file_fixture("photos/photo.jpg").binread, response.body.b
    assert_equal "max-age=86400, private", response.headers["Cache-Control"]
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
  end

  test "a visitor is sent to the sign-in" do
    photo_of(@student)

    assert_redirected_to new_session_path
  end

  test "the student, the teacher of their classroom and the team receive the photo" do
    [ @student, @teacher, create_team_member ].each do |reader|
      sign_in_as reader
      photo_of(@student)

      assert_photo_served
      sign_out
    end
  end

  test "another student and a teacher of another classroom are forbidden" do
    [ create_student(classroom: @classroom), create_teacher(classrooms: [ create_classroom ]) ].each do |reader|
      sign_in_as reader
      photo_of(@student)

      assert_response :forbidden
      assert_not_equal file_fixture("photos/photo.jpg").binread, response.body.b
      sign_out
    end
  end

  test "an account without a photo, or unknown: not found" do
    sign_in_as create_team_member

    photo_of(create_student)
    assert_response :not_found
    get account_photo_path("inconnu")
    assert_response :not_found
  end
end
