require "test_helper"

module Entities
  module Classroom
    # CN-02, CN-03, ADR-0059 : la classe ajoutée prend le préfixe du barème et le numéro suivant le plus grand ; la
    # dernière est celle au plus grand numéro, dans l'ordre de la fiche.
    class ClassroomNumberingTest < ActiveSupport::TestCase
      test "le préfixe est celui du barème : niveau, puis série s'il y en a une" do
        assert_equal "6ème", ClassroomNumbering.prefix(level_name: "6ème", series_name: nil)
        assert_equal "Tle A1", ClassroomNumbering.prefix(level_name: "Tle", series_name: "A1")
      end

      test "le nom suivant prend le plus grand numéro du préfixe, plus un, même s'il manque un numéro" do
        taken = Set["Tle D 1", "Tle D 3", "Tle A1 7", "6ème 9", "Tle D bilingue"]

        assert_equal "Tle D 4", ClassroomNumbering.next_name(prefix: "Tle D", taken:)
        assert_equal "Tle A1 8", ClassroomNumbering.next_name(prefix: "Tle A1", taken:)
        assert_equal "Tle A2 1", ClassroomNumbering.next_name(prefix: "Tle A2", taken:)
      end

      test "un préfixe qui en contient un autre ne le trouble pas, et les caractères spéciaux sont échappés" do
        taken = [ "Tle A1 2", "1ère (bis) 3" ]

        assert_equal "Tle A 1", ClassroomNumbering.next_name(prefix: "Tle A", taken:)
        assert_equal "1ère (bis) 4", ClassroomNumbering.next_name(prefix: "1ère (bis)", taken:)
      end

      test "la dernière est celle au plus grand numéro final, un nom sans numéro passant avant la première" do
        assert_equal "6ème 10", ClassroomNumbering.last(names: [ "6ème 2", "6ème 10", "6ème bilingue", "6ème 9" ])
        assert_equal "6ème 1", ClassroomNumbering.last(names: [ "6ème bilingue", "6ème 1" ])
        assert_equal "6ème b", ClassroomNumbering.last(names: [ "6ème a", "6ème b" ])
        assert_nil ClassroomNumbering.last(names: [])
      end

      # ADR-0098 : seul le suffixe se saisit ; le préfixe du barème est toujours devant.
      test "le nom complet est le préfixe, une espace, puis le suffixe compacté" do
        assert_equal "6ème A", ClassroomNumbering.full_name(prefix: "6ème", suffix: "  A ")
        assert_equal "Tle D Excellence 2", ClassroomNumbering.full_name(prefix: "Tle D", suffix: "Excellence   2")
        assert_equal "6ème ", ClassroomNumbering.full_name(prefix: "6ème", suffix: nil)
      end

      test "le suffixe d'un nom de ce préfixe ; vide pour un nom qui n'en vient pas" do
        assert_equal "3", ClassroomNumbering.suffix_of(name: "6ème 3", prefix: "6ème")
        assert_equal "Excellence 2", ClassroomNumbering.suffix_of(name: "Tle D Excellence 2", prefix: "Tle D")
        assert_equal "", ClassroomNumbering.suffix_of(name: "Tle C 3", prefix: "Tle D")
        assert_equal "", ClassroomNumbering.suffix_of(name: "Tle D", prefix: "Tle D")
        assert_equal "", ClassroomNumbering.suffix_of(name: "6èmeA", prefix: "6ème")
      end
    end
  end
end
