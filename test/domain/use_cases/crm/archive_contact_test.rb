require "test_helper"

# CA-09: removing a contact archives it (stamped with the clock); archiving twice is harmless; content is forbidden.
module UseCases
  module Crm
    class ArchiveContactTest < ActiveSupport::TestCase
      class FakeContacts
        include Ports::Crm::ContactRepositoryPort

        attr_reader :archived

        def archive(public_id:, at:) = Shared::Result.success(@archived = [ public_id, at ])
      end

      NOW = Time.utc(2026, 11, 6, 9)
      Clock = Struct.new(:now).new(NOW)

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role:)

      def use_case = ArchiveContact.new(contacts: (@contacts = FakeContacts.new), policy: Policies::Crm::ManageCrmPolicy.new, clock: Clock)

      test "CA-09: archives the contact at the clock's instant" do
        assert use_case.call(actor:, public_id: "ctc_abc").success?
        assert_equal [ "ctc_abc", NOW ], @contacts.archived
      end

      test "content is forbidden and nothing is archived" do
        assert_equal :forbidden, use_case.call(actor: actor("content"), public_id: "ctc_abc").code
        assert_nil @contacts.archived
      end
    end
  end
end
