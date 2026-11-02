require "test_helper"

module Entities
  module Catalog
    # ADR-0123 : la liste explicite des dossiers de niveaux du programme contenus-v3-tous-niveaux.
    class V3ProgrammeLevelsTest < ActiveSupport::TestCase
      test "the Tle and 1ère folders, and those of 2nde, 4ème, 5ème and 6ème to come, belong to the programme" do
        %w[tle tle-a1 tle-a2 tle-c tle-d 1ere 1ere-a1 1ere-a2 1ere-c 1ere-d 2nde 2nde-a 2nde-c 4eme 5eme 6eme].each do |folder|
          assert V3ProgrammeLevels.include?(folder), folder
        end
      end

      test "3ème (an earlier programme), an unknown folder, a look-alike and nil do not" do
        [ "3eme", "tle-x", "tlec", "1ere-", "../tle", "TLE", "", nil ].each { assert_not V3ProgrammeLevels.include?(it), it.inspect }
      end
    end
  end
end
