require "test_helper"

module Entities
  module Billing
    # ADR cartes-activation §4.2 : 12 signes tirés sur 31, saisie normalisée, affichage XXXX-XXXX-XXXX.
    class ActivationCodeTest < ActiveSupport::TestCase
      test "l'alphabet compte 31 signes sans 0, O, 1, I ni L" do
        assert_equal 31, ActivationCode::ALPHABET.length
        assert_equal ActivationCode::ALPHABET.chars.uniq, ActivationCode::ALPHABET.chars
        assert_empty ActivationCode::ALPHABET.chars & %w[0 O 1 I L]
      end

      test "génère 12 signes de l'alphabet, différents d'un tirage à l'autre" do
        codes = Array.new(50) { ActivationCode.generate }

        assert(codes.all? { it.match?(/\A[#{ActivationCode::ALPHABET}]{12}\z/) })
        assert_equal 50, codes.uniq.size
      end

      test "normalise les minuscules, espaces et tirets" do
        assert_equal "K7QHM3XP9TRA", ActivationCode.normalize(" k7qh-m3xp 9tra ")
        assert_equal "", ActivationCode.normalize(nil)
      end

      test "affiche par groupes de quatre" do
        assert_equal "K7QH-M3XP-9TRA", ActivationCode.format("K7QHM3XP9TRA")
      end

      test "reconnaît un code bien formé après normalisation" do
        assert ActivationCode.well_formed?("K7QHM3XP9TRA")
        assert_not ActivationCode.well_formed?("K7QHM3XP9TR0")
        assert_not ActivationCode.well_formed?("K7QH")
      end
    end
  end
end
