require "test_helper"

module Entities
  module School
    # ADR-0057 (CE-04, CE-09): the school code of a teacher's sign-up — 6 symbols out of 32, never mistaken for a
    # classroom code.
    class SchoolCodeTest < ActiveSupport::TestCase
      test "6 symboles parmi 32 : lettres sans i ni o, chiffres de 2 à 9" do
        assert_equal 32, SchoolCode::SYMBOLS.size
        assert_empty SchoolCode::SYMBOLS & %w[i o 0 1]
        assert_equal 32**6, SchoolCode::SPACE
        50.times do
          code = SchoolCode.generate(random: Random.new(it))
          assert SchoolCode.valid?(code), code
          assert_equal 6, code.size
        end
        assert SchoolCode.valid?(SchoolCode.generate)
      end

      test "le format refuse les caractères ambigus, les majuscules et les mauvaises longueurs" do
        %w[k7m4q k7m4qz2 k7m4q0 k7m4q1 k7i4qz k7o4qz K7M4QZ k7m-4qz].each { |code| assert_not SchoolCode.valid?(code), code }
        assert_not SchoolCode.valid?(nil)
        assert SchoolCode.valid?("k7m4qz")
        assert SchoolCode.valid?("abcdef")
        assert SchoolCode.valid?("234567")
      end

      test "ne se confond jamais avec un code de classe" do
        assert_not SchoolCode.valid?(Entities::Classroom::JoinCode.generate)
        assert SchoolCode.classroom_code?("kfm37")
        assert_not SchoolCode.classroom_code?("k7m4qz")
      end

      test "tire des codes distincts hors des codes pris, et complète l'ensemble" do
        taken = Set.new([ SchoolCode.generate(random: Random.new(1)) ])
        codes = SchoolCode.generate_unique(count: 300, taken:, random: Random.new(1))

        assert_equal 300, codes.uniq.size
        assert_equal 301, taken.size
        assert codes.all? { SchoolCode.valid?(it) }
        assert_not_includes codes, taken.first
      end

      test "refuse de tirer au-delà de l'espace libre" do
        assert_raises(ArgumentError) { SchoolCode.generate_unique(count: SchoolCode::SPACE + 1, taken: Set.new) }
      end

      test "normalise la saisie : espaces et tirets retirés, minuscules" do
        assert_equal "k7m4qz", SchoolCode.normalize(" K7M-4qz ")
        assert_equal "k7m4qz", SchoolCode.normalize("k7m 4 q z")
        assert_equal "k7m4qz", SchoolCode.normalize("K7M - 4QZ")
        assert_equal "", SchoolCode.normalize(nil)
      end

      test "s'affiche en majuscules, en deux groupes de trois" do
        assert_equal "K7M-4QZ", SchoolCode.display("k7m4qz")
        assert_nil SchoolCode.display(nil)
      end
    end
  end
end
