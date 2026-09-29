require "test_helper"

module Queries
  module Shared
    # UDR-0054 §3.9 — the name fragment shared by every search-as-you-type list: no case, no accents, LIKE escaped.
    class TextSearchTest < ActiveSupport::TestCase
      def names(term, columns: [ "schools.name" ])
        TextSearch.apply(Orm::School.all, term, columns:).order(:name).pluck(:name)
      end

      setup do
        drena = create_drena
        [ [ "Lycée Émile Zola", "LEZ" ], [ "Collège Saint-Viateur", "CSV" ], [ "École 100%", nil ], [ "Lycée A_B", nil ],
          [ "Lycée AxB", nil ] ].each { |name, sigle| create_school(drena:, name:, sigle:) }
      end

      test "matches a fragment of the name whatever its case and accents" do
        assert_equal [ "Lycée Émile Zola" ], names("EMILE")
        assert_equal [ "Lycée Émile Zola" ], names("émile zo")
        assert_equal [ "École 100%" ], names("ecole")
      end

      test "a blank term leaves the scope untouched" do
        scope = Orm::School.all

        assert_same scope, TextSearch.apply(scope, "   ", columns: [ "schools.name" ])
        assert_same scope, TextSearch.apply(scope, nil, columns: [ "schools.name" ])
      end

      test "several columns are searched together" do
        assert_equal [ "Collège Saint-Viateur" ], names("csv", columns: [ "schools.name", "schools.sigle" ])
      end

      test "LIKE wildcards typed by the person are searched literally" do
        assert_equal [ "Lycée A_B" ], names("a_b")
        assert_equal [ "École 100%" ], names("0%")
      end

      test "normalize squishes, lowercases and strips accents like the database side" do
        assert_equal "lycee emile", TextSearch.normalize("  Lycée   ÉMILE ")
        assert_equal "", TextSearch.normalize(nil)
      end
    end
  end
end
