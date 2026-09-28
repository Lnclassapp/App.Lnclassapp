require "test_helper"

# ADR-0060: the address of a photo is the authenticated route of the account, with the version of the file; without a
# photo, there is no address and ui_avatar shows the initials.
class ProfilePhotosHelperTest < ActionView::TestCase
  test "an account with a photo has the address of its photo, versioned" do
    assert_equal "/accounts/abc123/photo?v=XyZ-_", account_photo_src("abc123", "XyZ-_")
  end

  test "an account without a photo has no address" do
    assert_nil account_photo_src("abc123", nil)
  end
end
