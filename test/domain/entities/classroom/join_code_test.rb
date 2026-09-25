require "test_helper"

module Entities
  module Classroom
    class JoinCodeTest < ActiveSupport::TestCase
      test "3 lettres sans i ni o, puis 2 chiffres de 2 à 9" do
        assert_equal 24, JoinCode::LETTERS.size
        assert_equal 884_736, JoinCode::SPACE
        50.times do
          code = JoinCode.generate(random: Random.new(it))
          assert JoinCode.valid?(code), code
        end
        assert JoinCode.valid?(JoinCode.generate)
      end

      test "le format refuse les caractères ambigus" do
        %w[abi23 abc01 ab234 abcd2 ABC23].each { |code| assert_not JoinCode.valid?(code), code }
      end

      test "tire des codes distincts hors des codes pris, et complète l'ensemble" do
        taken = Set.new([ JoinCode.generate(random: Random.new(1)) ])
        codes = JoinCode.generate_unique(count: 200, taken:, random: Random.new(1))

        assert_equal 200, codes.uniq.size
        assert_equal 201, taken.size
        assert codes.all? { JoinCode.valid?(it) }
      end

      test "refuse de tirer au-delà de l'espace libre" do
        assert_raises(ArgumentError) { JoinCode.generate_unique(count: JoinCode::SPACE + 1, taken: Set.new) }
      end

      test "normalise la saisie et l'affiche en majuscules" do
        assert_equal "abc23", JoinCode.normalize(" AB C23 ")
        assert_equal "", JoinCode.normalize(nil)
        assert_equal "ABC23", JoinCode.display("abc23")
        assert_nil JoinCode.display(nil)
      end
    end
  end
end
