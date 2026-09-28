require "test_helper"

# ADR-0060: the Active Storage routes are not drawn; the rich text editor, which refuses attachments, gets empty upload
# addresses instead of asking Action Text for routes that do not exist.
class RichTextHelperTest < ActionView::TestCase
  test "the editor has no direct upload nor blob address" do
    assert_equal({ direct_upload_url: "", blob_url_template: "" }, rich_text_without_uploads)
  end
end
