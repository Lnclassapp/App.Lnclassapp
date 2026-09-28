require "test_helper"

# ADR-0060: the profile photo is an Active Storage attachment of the account, on the configured service (the bucket in
# production); replacing or removing it erases the old file; no analysis job looks for libvips.
module Repositories
  module Identity
    class ProfilePhotoStoreTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      setup do
        @store = ProfilePhotoStore.new
        @user = create_student
        @jpeg = file_fixture("photos/photo.jpg").binread
      end

      def blob = @user.reload.photo.blob
      def stored?(blob) = ActiveStorage::Blob.service.exist?(blob.key)

      test "attach stores the bytes with their type, without analysis; read gives them back" do
        assert_not @store.attached?(user_id: @user.id)
        assert_nil @store.read(user_id: @user.id)

        assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
          assert @store.attach(user_id: @user.id, data: @jpeg, content_type: "image/jpeg")
        end

        assert @store.attached?(user_id: @user.id)
        assert_equal Ports::Identity::ProfilePhotoStorePort::StoredPhoto.new(content_type: "image/jpeg", data: @jpeg),
                     @store.read(user_id: @user.id)
        assert_equal [ "photo.jpg", "image/jpeg", @jpeg.bytesize ], [ blob.filename.to_s, blob.content_type, blob.byte_size ]
        assert stored?(blob)
      end

      test "a new photo replaces the old one, whose file is erased" do
        @store.attach(user_id: @user.id, data: @jpeg, content_type: "image/jpeg")
        old = blob

        perform_enqueued_jobs do
          @store.attach(user_id: @user.id, data: file_fixture("photos/photo_lossy.webp").binread, content_type: "image/webp")
        end

        assert_equal [ "photo.webp", "image/webp" ], [ blob.filename.to_s, blob.content_type ]
        assert_not ActiveStorage::Blob.exists?(old.id)
        assert_not stored?(old)
      end

      test "remove erases the file at once and says whether there was a photo" do
        @store.attach(user_id: @user.id, data: file_fixture("photos/photo.png").binread, content_type: "image/png")
        old = blob

        assert @store.remove(user_id: @user.id)

        assert_not @store.attached?(user_id: @user.id)
        assert_not stored?(old)
        assert_not ActiveStorage::Blob.exists?(old.id)
        assert_not @store.remove(user_id: @user.id)
      end
    end
  end
end
