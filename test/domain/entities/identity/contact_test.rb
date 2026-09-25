require "test_helper"

module Entities
  module Identity
    class ContactTest < ActiveSupport::TestCase
      test "garde un numéro à 10 chiffres valide" do
        assert_equal "0701020304", Contact.normalize("0701020304")
      end

      test "retire espaces, points et tirets" do
        assert_equal "0501020304", Contact.normalize("05 01.02-03 04")
      end

      test "retire le préfixe 00225 sur 15 chiffres et 225 sur 13" do
        assert_equal "0101020304", Contact.normalize("00225 01 01 02 03 04")
        assert_equal "0701020304", Contact.normalize("+225 07 01 02 03 04")
      end

      test "renvoie nil pour un numéro invalide ou absent" do
        assert_nil Contact.normalize("0801020304")
        assert_nil Contact.normalize("070102030")
        assert_nil Contact.normalize(nil)
      end
    end
  end
end
