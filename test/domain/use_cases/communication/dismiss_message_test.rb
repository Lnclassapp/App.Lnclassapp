require "test_helper"

module UseCases
  module Communication
    # ADR-0078 §4.2, AN-12, AN-13: a student hides a message they read, on all their devices (a dismissal row); an official
    # or unreadable message is refused and nothing is written. Without database: the ports are faked.
    class DismissMessageTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 4, 10)

      class FakeMessages
        include Ports::Communication::MessageRepositoryPort

        def initialize(message, author_role) = (@message, @author_role = message, author_role)
        def find_by_public_id(public_id:) = (@message if @message.public_id == public_id)
        def author_role(message:) = @author_role
      end

      class FakeReadable
        include Ports::Communication::ReadableMessagesPort

        attr_reader :asked

        def initialize(readable) = @readable = readable
        def reader_for(actor:) = Entities::Communication::Reader.new(user_id: actor.user_id, role: actor.role, school_id: 7, classroom_id: 4)

        def readable?(reader:, public_id:, now:)
          @asked = [ reader.user_id, public_id, now ]
          @readable
        end
      end

      class FakeDismissals
        include Ports::Communication::DismissalRepositoryPort

        attr_reader :dismissed

        def initialize = @dismissed = []

        def dismiss(message_id:, user_id:, at:)
          @dismissed << [ message_id, user_id, at ]
          true
        end
      end

      class FakeClock
        def now = NOW
      end

      setup do
        @message = Entities::Communication::Message.new(id: 3, public_id: "msg", author_id: 99, title: "Nouvelles fiches",
                                                        body: "En ligne.", audience: "classrooms", school_id: 7,
                                                        classroom_ids: [ 4 ], illustration: "sheets", status: "published")
        @awa = Entities::Identity::Actor.new(user_id: 1, role: :student)
      end

      def use_case(readable: true, author_role: :teacher)
        @readable = FakeReadable.new(readable)
        @dismissals = FakeDismissals.new
        DismissMessage.new(messages: FakeMessages.new(@message, author_role), readable: @readable, dismissals: @dismissals,
                           policy: Policies::Communication::DismissPolicy.new, clock: FakeClock.new)
      end

      test "AN-12 — the student's dismissal is written, at the current time, for a message they read now" do
        result = use_case.call(actor: @awa, public_id: "msg")

        assert result.success?
        assert_equal [ [ 3, 1, NOW ] ], @dismissals.dismissed
        assert_equal [ 1, "msg", NOW ], @readable.asked
      end

      test "AN-13 — an official message is refused, and no dismissal is written" do
        result = use_case(author_role: :school_admin).call(actor: @awa, public_id: "msg")

        assert_equal :forbidden, result.code
        assert_empty @dismissals.dismissed
      end

      test "a message the student does not read is refused, and no dismissal is written" do
        assert_equal :forbidden, use_case(readable: false).call(actor: @awa, public_id: "msg").code
        assert_empty @dismissals.dismissed
      end

      test "an unknown message: not_found" do
        assert_equal :not_found, use_case.call(actor: @awa, public_id: "inconnu").code
        assert_empty @dismissals.dismissed
      end
    end
  end
end
