require "test_helper"

module Dtos
  module Identity
    class ContactChangeInputTest < ActiveSupport::TestCase
      def build(**overrides)
        ContactChangeInput.new(current_pin: "2468", contact: "07 11 22 33 44", contact_confirmation: "0711223344",
                               ip: "1.2.3.4", user_agent: "Firefox", **overrides)
      end

      def errors(**overrides) = build(**overrides).tap(&:validate).errors

      test "une saisie complète est valide ; les deux numéros sont normalisés, la saisie brute est gardée" do
        input = build

        assert input.valid?
        assert_equal [ "0711223344", "0711223344", "07 11 22 33 44", "0711223344" ],
                     [ input.contact, input.contact_confirmation, input.raw_contact, input.raw_contact_confirmation ]
      end

      test "exige le PIN actuel, à 4 chiffres" do
        assert errors(current_pin: "").of_kind?(:current_pin, :blank)
        assert errors(current_pin: "12a4").of_kind?(:current_pin, :invalid)
        assert_not errors(current_pin: "").of_kind?(:current_pin, :invalid)
      end

      test "distingue un numéro absent d'un numéro hors format" do
        assert errors(contact: "", contact_confirmation: "").of_kind?(:contact, :blank)
        assert errors(contact: "0811223344", contact_confirmation: "0811223344").of_kind?(:contact, :invalid)
        assert_not errors(contact: "0811223344").of_kind?(:contact, :blank)
        assert ContactChangeInput.new.tap(&:validate).errors.of_kind?(:contact, :blank)
      end

      test "la confirmation doit désigner le même numéro, quelle que soit sa mise en forme" do
        assert build(contact_confirmation: "+225 07 11 22 33 44").valid?
        assert errors(contact_confirmation: "0711223345").of_kind?(:contact_confirmation, :confirmation)
        assert errors(contact_confirmation: "").of_kind?(:contact_confirmation, :confirmation)
      end

      test "un numéro hors format ne reçoit pas en plus une erreur de confirmation" do
        assert_not errors(contact: "0811223344", contact_confirmation: "0711223344").of_kind?(:contact_confirmation, :confirmation)
      end
    end
  end
end
