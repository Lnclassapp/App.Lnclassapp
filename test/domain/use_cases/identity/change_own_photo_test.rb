require "test_helper"

# PH-01, PH-03, PH-04, PH-06, ADR-0060: a person adds or replaces their own photo; only a small, clean image is stored,
# and the change is audited with its format, weight and size — never the image.
module UseCases
  module Identity
    class ChangeOwnPhotoTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 12)
      Clock = Data.define(:now)

      class FakeAudit
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize = @entries = []
        def record(**entry) = @entries << entry
      end

      setup do
        @user = Entities::Identity::User.new(id: 3, first_name: "Aya", last_name: "Koné", role: "student")
        @photos = FakeProfilePhotoStore.new
        @audit = FakeAudit.new
        @transaction = FakeTransaction.new
      end

      def change(name, actor: Entities::Identity::Actor.new(user_id: 3, role: :student))
        photo = name && StringIO.new(file_fixture("photos/#{name}").binread)
        ChangeOwnPhoto.new(photos: @photos, audit_log: @audit, transaction: @transaction,
                           policy: Policies::Identity::UpdateSelfPolicy.new, clock: Clock.new(NOW))
                      .call(actor:, user: @user, dto: Dtos::Identity::ProfilePhotoInput.new(photo:), ip: "1.2.3.4")
      end

      test "a small photo is stored without its Exif and audited with its format, weight and size, in one transaction" do
        result = change("photo_exif.jpg")

        assert result.success?
        stored = @photos.read(user_id: 3)
        assert_equal "image/jpeg", stored.content_type
        assert_not Entities::Identity::ImageHeader.read(stored.data).metadata
        assert_equal [ { action: "profile.photo_changed", actor_id: 3, at: NOW, subject_type: "User", subject_id: 3,
                         metadata: { content_type: "image/jpeg", byte_size: stored.data.bytesize, width: 64, height: 48,
                                     replaced: false }, ip: "1.2.3.4" } ], @audit.entries
        assert_equal 1, @transaction.calls
      end

      test "a second photo replaces the first, and the audit says so" do
        change("photo.jpg")
        change("photo_lossy.webp")

        assert_equal "image/webp", @photos.read(user_id: 3).content_type
        assert_equal [ false, true ], @audit.entries.map { it[:metadata][:replaced] }
      end

      test "another account is refused before the file is even checked" do
        result = change(nil, actor: Entities::Identity::Actor.new(user_id: 4, role: :team))

        assert_equal :forbidden, result.code
        assert_empty @photos.writes
      end

      test "no file, a PDF, a too wide image: invalid with the errors of the form; nothing stored nor audited" do
        { nil => "Choisissez une photo.", "document.pdf" => "Choisissez une photo JPEG, PNG ou WebP.",
          "too_wide.png" => "La photo mesure 1024 pixels de côté au plus." }.each do |name, message|
          result = change(name)

          assert_equal :invalid, result.code, name
          assert_equal({ photo: [ message ] }, result.errors, name)
        end
        assert_empty @photos.writes
        assert_empty @audit.entries
        assert_equal 0, @transaction.calls
      end
    end
  end
end
