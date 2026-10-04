require "test_helper"

module UseCases
  module Communication
    # AN-12, UDR-0071 §3.5 and §3.7: « Annuler » and « Réafficher » give a hidden message back to the student, under the same
    # right as hiding it (DismissPolicy). Without database: the ports are faked.
    class RestoreMessageTest < ActiveSupport::TestCase
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

        attr_reader :restored

        def initialize = @restored = []

        def restore(message_id:, user_id:)
          @restored << [ message_id, user_id ]
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
        RestoreMessage.new(messages: FakeMessages.new(@message, author_role), readable: @readable, dismissals: @dismissals,
                           policy: Policies::Communication::DismissPolicy.new, clock: FakeClock.new)
      end

      test "AN-12 — « Annuler » removes the student's own dismissal of a message they read" do
        result = use_case.call(actor: @awa, public_id: "msg")

        assert result.success?
        assert_equal [ [ 3, 1 ] ], @dismissals.restored
        assert_equal [ 1, "msg", NOW ], @readable.asked
      end

      test "refused outside the right to hide: nothing is removed" do
        assert_equal :forbidden, use_case(readable: false).call(actor: @awa, public_id: "msg").code
        assert_equal :forbidden, use_case.call(actor: Entities::Identity::Actor.new(user_id: 2, role: :teacher, school_id: 7),
                                               public_id: "msg").code
        assert_empty @dismissals.restored
      end

      test "an unknown message: not_found" do
        assert_equal :not_found, use_case.call(actor: @awa, public_id: "inconnu").code
        assert_empty @dismissals.restored
      end
    end
  end
end
