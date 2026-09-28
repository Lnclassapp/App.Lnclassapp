require "test_helper"

# PH-03, PH-06, ADR-0060: a person removes their own photo; the file is erased and the removal audited. Without a
# photo, nothing happens and nothing is traced.
module UseCases
  module Identity
    class RemoveOwnPhotoTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)
      PHOTO = Ports::Identity::ProfilePhotoStorePort::StoredPhoto.new(content_type: "image/webp", data: "RIFF")

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 3, first_name: "Aya", last_name: "Koné", role: "student")
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def remove(photos, actor: Entities::Identity::Actor.new(user_id: 3, role: :student))
        RemoveOwnPhoto.new(photos:, audit_log: @audit, transaction: @transaction,
                           policy: Policies::Identity::UpdateSelfPolicy.new, clock: Clock.new(NOW))
                      .call(actor:, user: @user, ip: "1.2.3.4")
      end

      test "the photo is erased and the removal audited first, in one transaction; the result says a photo was removed" do
        photos = FakeProfilePhotoStore.new(3 => PHOTO)

        result = remove(photos)

        assert result.success?
        assert result.value
        assert_nil photos.read(user_id: 3)
        assert_equal [ { action: "profile.photo_removed", actor_id: 3, at: NOW, subject_type: "User", subject_id: 3,
                         ip: "1.2.3.4" } ], @audit.entries
        assert_equal 1, @transaction.calls
      end

      test "without a photo: success, nothing erased, nothing audited" do
        photos = FakeProfilePhotoStore.new

        result = remove(photos)

        assert result.success?
        assert_not result.value
        assert_empty photos.writes
        assert_empty @audit.entries
      end

      test "another account is refused and the photo stays" do
        photos = FakeProfilePhotoStore.new(3 => PHOTO)

        assert_equal :forbidden, remove(photos, actor: Entities::Identity::Actor.new(user_id: 7, role: :team)).code
        assert_equal PHOTO, photos.read(user_id: 3)
        assert_empty @audit.entries
      end
    end
  end
end
