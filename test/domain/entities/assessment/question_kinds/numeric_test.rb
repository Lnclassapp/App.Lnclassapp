require "test_helper"

module Entities
  module Assessment
    module QuestionKinds
      # ADR-0091 §4.3 : un nombre saisi au clavier d'un téléphone, avec la virgule ou le point, le moins ASCII ou Unicode,
      # et les espaces des milliers. Le reste est illisible.
      class NumericTest < ActiveSupport::TestCase
        test "virgule ou point, moins ASCII ou Unicode, espaces des milliers" do
          assert_equal BigDecimal("3.5"), Numeric.parse("3,5")
          assert_equal BigDecimal("3.5"), Numeric.parse(" 3.5 ")
          assert_equal BigDecimal("-2"), Numeric.parse("−2")
          assert_equal BigDecimal("-2"), Numeric.parse("-2")
          assert_equal BigDecimal("1000.25"), Numeric.parse("1 000,25")
          assert_equal BigDecimal("12000"), Numeric.parse("12 000")
        end

        test "une saisie illisible rend nil" do
          [ "3,,5", "", " ", "abc", "3.", ",5", "--2", "2-", "1e3", "3,5,1", nil ].each do |text|
            assert_nil Numeric.parse(text), text.inspect
          end
        end
      end
    end
  end
end
