require "test_helper"

module Entities
  module Classroom
    # ADR-XXXX code-de-classe-a-six-caracteres (CA-B1): the code of a classroom, 6 symbols like the school code, stored in
    # lower case, displayed in upper case by groups of three.
    class JoinCodeTest < ActiveSupport::TestCase
      test "6 symbols out of 32, letters without i or o, digits from 2 to 9" do
        assert_equal 32, JoinCode::SYMBOLS.size
        assert_empty JoinCode::SYMBOLS & %w[i o 0 1]
        assert_equal 32**6, JoinCode::SPACE
        50.times do
          code = JoinCode.generate(random: Random.new(it))
          assert JoinCode.valid?(code), code
          assert_equal 6, code.size
        end
        assert JoinCode.valid?(JoinCode.generate)
      end

      test "the format is the one of the database constraint" do
        assert_equal "^[a-hj-np-z2-9]{6}$", JoinCode::FORMAT.source.sub("\\A", "^").sub("\\z", "$")
        %w[k7m4q k7m4qz2 k7m4q0 k7m4q1 k7i4qz k7o4qz K7M4QZ k7m-4qz].each { |code| assert_not JoinCode.valid?(code), code }
        assert_not JoinCode.valid?(nil)
        assert_not JoinCode.valid?("k7m4qz\n")
        assert JoinCode.valid?("k7m4qz")
        assert JoinCode.valid?("234567")
      end

      test "normalizes the typed code: spaces and dashes removed, lower case" do
        assert_equal "k7m4q2", JoinCode.normalize(" K7M 4q2 ")
        assert_equal "k7m4q2", JoinCode.normalize("k7m-4q2")
        assert_equal "k7m4q2", JoinCode.normalize("K 7 M 4 Q 2")
        assert_equal "", JoinCode.normalize(nil)
      end

      test "is displayed in upper case, in two groups of three" do
        assert_equal "K7M 4Q2", JoinCode.display("k7m4q2")
        assert_nil JoinCode.display(nil)
      end

      test "draws a free code: the first one not taken" do
        drawn = []
        code = JoinCode.generate_free(random: Random.new(1)) { |candidate| drawn << candidate; drawn.size < 3 }

        assert_equal 3, drawn.size
        assert_equal drawn.last, code
        assert JoinCode.valid?(code)
      end

      test "gives up after five collisions" do
        tries = 0

        assert_raises(JoinCode::Exhausted) { JoinCode.generate_free { tries += 1 } }
        assert_equal JoinCode::ATTEMPTS, tries
        assert_equal 5, JoinCode::ATTEMPTS
      end
    end
  end
end
