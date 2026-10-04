require "test_helper"

# ADR-0045 §4 and ADR-0069 §4.4: one image and one audio file per message, on the configured service (the bucket in
# production), never analysed; the audio is read by byte range, for playback and resumption on a mobile network.
module Repositories
  module Communication
    class AttachmentStoreTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      StoredFile = Ports::Communication::AttachmentStorePort::StoredFile
      AUDIO = ("ID3".b + (0..255).map(&:chr).join.b * 4).freeze

      setup do
        @store = AttachmentStore.new
        @message = create_message(author: create_school_admin)
        @png = file_fixture("photos/photo.png").binread
      end

      def attach_audio(data = AUDIO)
        @store.attach(message_id: @message.id, kind: :audio, io: StringIO.new(data), content_type: "audio/mpeg",
                      filename: "message.mp3")
      end

      def blob(kind) = @message.reload.public_send(kind).blob
      def stored?(blob) = ActiveStorage::Blob.service.exist?(blob.key)

      test "attach stores each kind with its type and name, without analysis; read gives it back whole" do
        assert_not @store.attached?(message_id: @message.id, kind: :image)
        assert_nil @store.read(message_id: @message.id, kind: :image)

        assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
          assert @store.attach(message_id: @message.id, kind: :image, io: StringIO.new(@png), content_type: "image/png",
                               filename: "affiche.png")
          assert attach_audio
        end

        assert @store.attached?(message_id: @message.id, kind: :image)
        assert_equal StoredFile.new(content_type: "image/png", data: @png, byte_size: @png.bytesize, range: nil),
                     @store.read(message_id: @message.id, kind: :image)
        assert_equal [ "affiche.png", "image/png" ], [ blob(:image).filename.to_s, blob(:image).content_type ]
        assert_equal [ "message.mp3", "audio/mpeg", AUDIO.bytesize ], [ blob(:audio).filename.to_s, blob(:audio).content_type, blob(:audio).byte_size ]
      end

      test "a kind is image or audio, as a symbol or a string; anything else is refused" do
        attach_audio

        assert @store.attached?(message_id: @message.id, kind: "audio")
        error = assert_raises(ArgumentError) { @store.read(message_id: @message.id, kind: :destroy) }
        assert_match "destroy", error.message
        assert @message.reload.persisted?
      end

      test "read gives a byte range of the file, and the size of the whole file" do
        attach_audio

        stored = @store.read(message_id: @message.id, kind: :audio, range: 0..3)

        assert_equal [ "ID3\x00".b, AUDIO.bytesize, 0..3, "audio/mpeg" ], [ stored.data, stored.byte_size, stored.range, stored.content_type ]
        assert_equal AUDIO.byteslice(100, 50), @store.read(message_id: @message.id, kind: :audio, range: 100...150).data
      end

      test "an open range reads to the end, a negative one the last bytes, an end beyond the file stops at its last byte" do
        attach_audio
        last = AUDIO.bytesize - 1
        read = ->(range) { @store.read(message_id: @message.id, kind: :audio, range:) }

        assert_equal [ AUDIO.byteslice(1000..), 1000..last ], [ read.call(1000..).data, read.call(1000..).range ]
        assert_equal [ AUDIO.byteslice(-10..), (last - 9)..last ], [ read.call(-10..).data, read.call(-10..).range ]
        assert_equal [ AUDIO, 0..last ], [ read.call(-5000..).data, read.call(-5000..).range ]
        assert_equal [ AUDIO.byteslice(1020..), 1020..last ], [ read.call(1020..5000).data, read.call(1020..5000).range ]
      end

      test "a range outside the file is ignored: the file is read whole, as HTTP allows" do
        attach_audio

        [ AUDIO.bytesize.., 10..5 ].each do |range|
          stored = @store.read(message_id: @message.id, kind: :audio, range:)

          assert_equal [ AUDIO, nil ], [ stored.data, stored.range ], range.inspect
        end
      end

      test "a new file replaces the old one, whose file is erased" do
        attach_audio
        old = blob(:audio)

        perform_enqueued_jobs { attach_audio("ID3 seconde version".b) }

        assert_equal "ID3 seconde version".b, @store.read(message_id: @message.id, kind: :audio).data
        assert_not ActiveStorage::Blob.exists?(old.id)
        assert_not stored?(old)
      end

      test "remove erases the file at once, says whether there was one, and leaves the other kind" do
        attach_audio
        @store.attach(message_id: @message.id, kind: :image, io: StringIO.new(@png), content_type: "image/png", filename: "a.png")
        old = blob(:audio)

        assert @store.remove(message_id: @message.id, kind: :audio)

        assert_not @store.attached?(message_id: @message.id, kind: :audio)
        assert_not stored?(old)
        assert_not @store.remove(message_id: @message.id, kind: :audio)
        assert @store.attached?(message_id: @message.id, kind: :image)
      end
    end
  end
end
