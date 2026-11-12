require "test_helper"

# CA-10: a contact needs a name and a known position; a phone number, when given, is a 10-digit Ivorian number (« 12345 » is refused).
module UseCases
  module Crm
    class AddContactTest < ActiveSupport::TestCase
      class FakeContacts
        include Ports::Crm::ContactRepositoryPort

        attr_reader :created

        def create(contact:) = Shared::Result.success(@created = contact)
      end

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role:)

      def call(actor: self.actor, **values)
        @contacts = FakeContacts.new
        input = { school_id: 31, full_name: "Mme Kouassi", position: "director", phone: "0701020304", note: nil }.merge(values)
        AddContact.new(contacts: @contacts, policy: Policies::Crm::ManageCrmPolicy.new).call(actor:, **input)
      end

      test "CA-09: adds a contact with its trimmed name, normalized phone and author" do
        result = call(full_name: "  Mme Kouassi ", phone: "07 01 02 03 04", note: " Joignable le matin ")

        assert result.success?
        assert_equal [ "Mme Kouassi", "0701020304", "Joignable le matin", 7, 31 ],
                     @contacts.created.then { [ it.full_name, it.phone, it.note, it.created_by_id, it.school_id ] }
        assert_not @contacts.created.archived?
      end

      test "CA-10: 12345 is refused and nothing is written" do
        result = call(phone: "12345")

        assert_equal :invalid, result.code
        assert_equal [ :invalid ], result.errors[:phone]
        assert_nil @contacts.created
      end

      test "the phone number is optional" do
        assert_nil call(phone: " ").value.phone
      end

      test "name, position and note are checked" do
        assert_equal [ :blank ], call(full_name: " ").errors[:full_name]
        assert_equal [ :too_long ], call(full_name: "a" * 81).errors[:full_name]
        assert_equal [ :inclusion ], call(position: "king").errors[:position]
        assert_equal [ :too_long ], call(note: "a" * 501).errors[:note]
      end

      test "content is forbidden" do
        assert_equal :forbidden, call(actor: actor("content")).code
        assert_nil @contacts.created
      end
    end
  end
end
