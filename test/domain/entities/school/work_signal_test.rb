require "test_helper"

# AD-01 (UDR-0074 §2.5) : la pastille de la direction lit le taux de rendu à seuils fixes ; sans taux, pas de pastille.
module Entities
  module School
    class WorkSignalTest < ActiveSupport::TestCase
      test "vert à partir de 70 %" do
        [ 70, 85, 100 ].each { assert_equal :green, WorkSignal.for(it), "#{it} %" }
      end

      test "jaune de 40 à 69 %" do
        [ 40, 55, 69 ].each { assert_equal :yellow, WorkSignal.for(it), "#{it} %" }
      end

      test "rouge sous 40 %" do
        [ 0, 31, 39 ].each { assert_equal :red, WorkSignal.for(it), "#{it} %" }
      end

      test "aucun signal sans taux calculé" do
        assert_nil WorkSignal.for(nil)
      end

      test "les trois signaux, dans l'ordre de la légende" do
        assert_equal %i[green yellow red], WorkSignal::ALL
      end
    end
  end
end
