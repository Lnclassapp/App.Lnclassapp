require "test_helper"

module Entities
  module Classroom
    class InviteCodeTest < ActiveSupport::TestCase
      test "8 symbols from the class code alphabet" do
        assert_equal 8, InviteCode::LENGTH
        assert_equal JoinCode::SYMBOLS, InviteCode::ALPHABET
        50.times do
          code = InviteCode.generate(random: Random.new(it))
          assert InviteCode.valid?(code), code
          assert_equal 8, code.size
        end
      end

      test "generation is pure: same random, same code" do
        assert_equal InviteCode.generate(random: Random.new(1)), InviteCode.generate(random: Random.new(1))
      end

      test "the format is the one of the database constraint" do
        assert_equal "^[a-hjkmnp-z2-9]{8}$", InviteCode::FORMAT.source.sub("\\A", "^").sub("\\z", "$")
        %w[k7m4q2z k7m4q2zzz k7m4q2z0 k7m4q2z1 K7M4Q2ZZ k7i4q2zz].each { |code| assert_not InviteCode.valid?(code), code }
        assert_not InviteCode.valid?(nil)
      end

      test "normalize lowers case and drops spaces, or gives nil" do
        assert_equal "k7m4q2zz", InviteCode.normalize(" K7M4 q2zz\n")
        assert_nil InviteCode.normalize("  ")
        assert_nil InviteCode.normalize(nil)
      end
    end
  end
end
