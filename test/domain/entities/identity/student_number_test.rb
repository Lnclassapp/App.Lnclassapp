require "test_helper"

module Entities
  module Identity
    # ADR-0065 (ED-50): the MENA student number — 8 digits then a letter, normalised, masked outside the screens that need it.
    class StudentNumberTest < ActiveSupport::TestCase
      test "normalise : retire espaces, points, tirets et barres obliques, met en majuscules" do
        assert_equal "12345678A", StudentNumber.normalize(" 1234 5678-a ")
        assert_equal "12345678A", StudentNumber.normalize("1234.5678/A")
        assert_equal "12345678A", StudentNumber.normalize("12345678A")
      end

      test "une saisie vide donne nil" do
        [ nil, "", "   ", " - . / " ].each { assert_nil StudentNumber.normalize(it), it.inspect }
      end

      test "le format est 8 chiffres suivis d'une lettre majuscule" do
        assert StudentNumber.valid?("12345678A")
        %w[1234567A A12345678 12345678AB 123456789 12345678a 1234567AB].each { assert_not StudentNumber.valid?(it), it }
        assert_not StudentNumber.valid?(nil)
        assert_not StudentNumber.valid?("12345678A\n")
      end

      test "le masque ne laisse voir que les cinq derniers signes" do
        assert_equal "••••5678A", StudentNumber.mask("12345678A")
        assert_nil StudentNumber.mask(nil)
      end
    end
  end
end
