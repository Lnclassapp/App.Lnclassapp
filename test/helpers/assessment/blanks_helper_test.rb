require "test_helper"

# UDR-XXXX je-m-entraine-dans-la-fiche §3.3 : le texte d'une question découpé en morceaux de texte et en cases.
module Assessment
  class BlanksHelperTest < ActionView::TestCase
    test "un énoncé à deux cases rend le texte et les cases dans l'ordre, numérotées depuis 0" do
      assert_equal [ [ :text, "AN (cm) = " ], [ :blank, 0 ], [ :text, "   MN (cm) = " ], [ :blank, 1 ] ], blank_segments("AN (cm) = ___   MN (cm) = ___")
    end

    test "un énoncé sans case reste un seul morceau de texte" do
      assert_equal [ [ :text, "Calcule 2 + 2." ] ], blank_segments("Calcule 2 + 2.")
    end

    test "une case au début, deux cases collées, un texte après la dernière" do
      assert_equal [ [ :blank, 0 ], [ :text, " est " ], [ :blank, 1 ], [ :blank, 2 ], [ :text, " fin" ] ], blank_segments("___ est ______ fin")
    end

    test "aucun morceau de texte vide n'est rendu" do
      assert_equal [ [ :blank, 0 ] ], blank_segments("___")
      assert_empty blank_segments("")
      assert_empty blank_segments(nil)
    end

    test "le nombre de cases est celui des ___" do
      assert_equal 3, blank_segments("a ___ b ___ c ___").count { |kind, _| kind == :blank }
    end
  end
end
