require "test_helper"

module Entities
  module Identity
    # IE-03, IE-05 (ADR-0082 §4.4): one « Nom complet » field, Ivorian order. The first word is the last name, the rest
    # the first names; case is kept; under two words, no split.
    class FullNameTest < ActiveSupport::TestCase
      test "IE-03: the first word is the last name, every following word the first names, case kept" do
        assert_equal [ "N'GUESSAN", "Konan Jean-Baptiste" ], FullName.split("N'GUESSAN  Konan Jean-Baptiste")
        assert_equal [ "KOUASSI", "Aya Marie" ], FullName.split("KOUASSI Aya Marie")
        assert_equal [ "koné", "awa" ], FullName.split("koné awa")
      end

      test "spaces around and between the words are squeezed before the split" do
        assert_equal [ "Kouassi", "Aya Marie" ], FullName.split("  Kouassi \t Aya   Marie \n")
      end

      test "IE-05: a single word, a blank or nothing gives no split" do
        [ "Kouassi", "  Kouassi  ", "", "   ", nil ].each { assert_nil FullName.split(it), it.inspect }
      end
    end
  end
end
