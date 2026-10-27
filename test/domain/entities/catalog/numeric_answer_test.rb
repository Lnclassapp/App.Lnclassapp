require "test_helper"

module Entities
  module Catalog
    # contenu-en-blocs (#318), Lot C, CA-7 : la réponse numérique d'un exercice. Même règle que numeric_answer côté JS (bank.js).
    class NumericAnswerTest < ActiveSupport::TestCase
      PARSE = {
        "3,6" => 3.6, "3.6" => 3.6, " 3 , 6 " => 3.6, "4,20" => 4.2, "4.2" => 4.2, "12" => 12.0, "-1,5" => -1.5, "−1,5" => -1.5,
        "1 000,5" => 1000.5, "3/5" => 0.6, " 3 / 5 " => 0.6, "1,5/3" => 0.5, ".5" => 0.5, "4." => 4.0,
        "" => nil, "   " => nil, nil => nil, "abc" => nil, "3,6 cm" => nil, "3,,6" => nil, "3.6.1" => nil, "1/0" => nil, "1/" => nil,
        "/2" => nil, "1/2/3" => nil, "1e3" => nil, "0x10" => nil, "Infinity" => nil, "NaN" => nil, "--1" => nil
      }.freeze

      PARSE.each do |input, value|
        test "parse(#{input.inspect}) donne #{value.inspect}" do
          result = NumericAnswer.parse(input)

          value.nil? ? assert_nil(result) : assert_in_delta(value, result, 1e-9)
        end
      end

      CORRECT = {
        [ "3,6", 3.6 ] => true, [ "3.6", 3.6 ] => true, [ "4,20", 4.2 ] => true, [ "4.2", 4.2 ] => true, [ "4,2", 4.2 ] => true,
        [ "4,21", 4.2 ] => true, [ "4,19", 4.2 ] => true, [ "4,211", 4.2 ] => false, [ "3,62", 3.6 ] => false, [ "3,59", 3.6 ] => true,
        [ "18/5", 3.6 ] => true, [ "2/5", 0.4 ] => true, [ "", 3.6 ] => false, [ "abc", 3.6 ] => false, [ "1/0", 3.6 ] => false,
        [ "0", 0 ] => true, [ "9", 9 ] => true
      }.freeze

      CORRECT.each do |(input, expected), verdict|
        test "#{input.inspect} pour #{expected} est #{verdict ? 'juste' : 'faux'}" do
          assert_equal verdict, NumericAnswer.new(expected).correct?(input)
        end
      end

      test "un champ vide ou illisible est à compléter, pas à revoir" do
        answer = NumericAnswer.new(3.6)

        assert_equal :incomplete, answer.verdict(" ")
        assert_equal :incomplete, answer.verdict(nil)
        assert_equal :wrong, answer.verdict("abc")
        assert_equal :wrong, answer.verdict("3,62")
        assert_equal :correct, answer.verdict("3,6")
      end

      test "la tolérance est de 0,011" do
        assert_in_delta 0.011, NumericAnswer::TOLERANCE, 1e-12
      end

      test "format écrit à la française, deux décimales au plus" do
        assert_equal "3,6", NumericAnswer.format(3.6)
        assert_equal "4,5", NumericAnswer.format(4.5)
        assert_equal "3", NumericAnswer.format(3)
        assert_equal "0,33", NumericAnswer.format(1.0 / 3)
        assert_equal "-1,5", NumericAnswer.format(-1.5)
      end

      test "une réponse attendue qui n'est pas un nombre fini est refusée" do
        assert_raises(ArgumentError) { NumericAnswer.new("3,6") }
        assert_raises(ArgumentError) { NumericAnswer.new(Float::NAN) }
        assert_raises(ArgumentError) { NumericAnswer.new(nil) }
      end
    end
  end
end
