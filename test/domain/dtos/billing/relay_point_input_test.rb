require "test_helper"

# ADR-0126 §4.1, UDR-0159 §3.2 : le téléphone d'un point relais a dix chiffres ; absent, il est obligatoire, sinon invalide.
module Dtos
  module Billing
    class RelayPointInputTest < ActiveSupport::TestCase
      def input(phone) = RelayPointInput.new(name: "Boutique Awa", location: "Près du marché", phone:).tap(&:validate)

      test "dix chiffres, avec points ou tirets, s'écrivent par paires et sont valides" do
        [ "0700000000", "07.00.00.00.00", "07-00-00-00-00" ].each do |phone|
          form = input(phone)

          assert_empty form.errors, phone
          assert_equal "07 00 00 00 00", form.phone
        end
      end

      test "un téléphone absent est obligatoire" do
        [ nil, "", "   " ].each { assert input(it).errors.of_kind?(:phone, :blank), it.inspect }
      end

      test "un téléphone sans dix chiffres est invalide et reste tel que saisi" do
        [ "123", "07 00 00 00 0", "07a0000000" ].each do |phone|
          form = input(phone)

          assert form.errors.of_kind?(:phone, :invalid), phone
          assert_equal phone, form.phone
        end
      end
    end
  end
end
