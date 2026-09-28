require "test_helper"

# ADR-0060 (second challenge of PR #50): the Active Storage routes are not drawn, so a blob already attached to a rich
# text — inserted before attachments were refused, or directly in the base — is shown by its name and size, never by
# an address; the page answers 200 instead of « Can't resolve image into URL ».
class Identity::RichTextAttachmentTest < ActionDispatch::IntegrationTest
  test "a course whose content holds an image blob attachment is shown, with the file name and no Active Storage address" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("photos/photo.png").open, filename: "schema-secret.png",
                                                  content_type: "image/png")
    course = create_course(content: %(<p>Voir :</p><action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>))
    sign_in_as create_student

    get course_path(course.slug)

    assert_response :success
    assert_select ".trix-content figure.attachment" do
      assert_select ".attachment__name", "schema-secret.png"
      assert_select "img", 0
    end
    assert_not_includes response.body, "/rails/active_storage"
  end
end
