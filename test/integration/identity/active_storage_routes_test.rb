require "test_helper"

# ADR-0060 (challenge of PR #50): no feature serves or receives a file through the Active Storage routes, so they are
# not drawn: a leaked signed id opens nothing, and nobody creates a blob by direct upload.
class Identity::ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  test "an anonymous direct upload is not found, and creates no blob" do
    assert_no_difference -> { ActiveStorage::Blob.count } do
      post "/rails/active_storage/direct_uploads",
           params: { blob: { filename: "x.jpg", byte_size: 10, checksum: "1B2M2Y8AsgTpgAmY7PhCfg==", content_type: "image/jpeg" } },
           as: :json
    end

    assert_response :not_found
  end

  test "a leaked signed id of a photo opens nothing, by proxy, redirect or disk" do
    blob = attach_photo(create_student).photo.blob

    [ "/rails/active_storage/blobs/proxy/#{blob.signed_id}/photo.jpg", "/rails/active_storage/blobs/redirect/#{blob.signed_id}/photo.jpg",
      "/rails/active_storage/disk/anything/photo.jpg" ].each do |path|
      get path

      assert_response :not_found, path
    end
  end
end
