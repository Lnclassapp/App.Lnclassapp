require "test_helper"

module UseCases
  module Communication
    # ADR-0069 §4.4: a file of a message is read only after the reading rule (or as its author, the team, the moderating
    # direction), byte range included; any refusal or missing file is not_found. Without database: the ports are faked.
    class ReadMessageFileTest < ActiveSupport::TestCase
      StoredFile = Ports::Communication::AttachmentStorePort::StoredFile
      NOW = Time.utc(2026, 10, 4, 10)

      class FakeMessages
        include Ports::Communication::MessageRepositoryPort

        def initialize(message, author_role) = (@message, @author_role = message, author_role)
        def find_by_public_id(public_id:) = (@message if @message&.public_id == public_id)
        def author_role(message:) = @author_role
      end

      class FakeReadable
        include Ports::Communication::ReadableMessagesPort

        attr_reader :asked

        def initialize(readable) = @readable = readable
        def reader_for(actor:) = Entities::Communication::Reader.new(user_id: actor.user_id, role: actor.role, school_id: nil, classroom_id: 4)

        def readable?(reader:, public_id:, now:)
          @asked = [ reader.classroom_id, public_id, now ]
          @readable
        end
      end

      class FakeAttachments
        include Ports::Communication::AttachmentStorePort

        attr_reader :reads

        def initialize(file) = (@file, @reads = file, [])

        def read(message_id:, kind:, range: nil)
          @reads << [ message_id, kind, range ]
          @file
        end
      end

      class FakeClock
        def now = NOW
      end

      setup do
        @message = Entities::Communication::Message.new(id: 3, public_id: "msg", author_id: 99, title: "Nouvelles fiches",
                                                        body: "En ligne.", audience: "classrooms", school_id: 7,
                                                        classroom_ids: [ 4 ], illustration: "sheets", status: "published")
        @file = StoredFile.new(content_type: "audio/mpeg", data: "ID3".b, byte_size: 300, range: 0..2)
        @student = Entities::Identity::Actor.new(user_id: 1, role: :student)
      end

      def use_case(readable: true, file: @file, author_role: :teacher)
        @readable = FakeReadable.new(readable)
        @attachments = FakeAttachments.new(file)
        ReadMessageFile.new(messages: FakeMessages.new(@message, author_role), readable: @readable, attachments: @attachments,
                            policy: Policies::Communication::ReadFilePolicy.new, clock: FakeClock.new)
      end

      test "AN-09 — a reader receives the file, for the byte range asked, read by the rule at the current time" do
        result = use_case.call(actor: @student, public_id: "msg", kind: "audio", range: 0..2)

        assert_equal [ true, @file ], [ result.success?, result.value ]
        assert_equal [ [ 3, "audio", 0..2 ] ], @attachments.reads
        assert_equal [ 4, "msg", NOW ], @readable.asked
      end

      test "the author reads the file of a message the rule does not give him; the range is optional" do
        result = use_case(readable: false).call(actor: Entities::Identity::Actor.new(user_id: 99, role: :teacher, school_id: 7),
                                                public_id: "msg", kind: "image")

        assert result.success?
        assert_equal [ [ 3, "image", nil ] ], @attachments.reads
      end

      test "AN-09 — refused: not_found, and the file is never read" do
        result = use_case(readable: false).call(actor: @student, public_id: "msg", kind: "audio")

        assert_equal :not_found, result.code
        assert_empty @attachments.reads
      end

      test "an unknown message, or a kind other than image and audio: not_found" do
        assert_equal :not_found, use_case.call(actor: @student, public_id: "inconnu", kind: "audio").code
        assert_equal :not_found, use_case.call(actor: @student, public_id: "msg", kind: "destroy").code
        assert_empty @attachments.reads
      end

      test "a message without this file: not_found" do
        assert_equal :not_found, use_case(file: nil).call(actor: @student, public_id: "msg", kind: "image").code
      end
    end
  end
end
