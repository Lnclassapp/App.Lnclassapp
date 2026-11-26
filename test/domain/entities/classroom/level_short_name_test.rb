require "test_helper"

# accueil-enseignant-actions (UDR §3.2, CA-4) : le nom court d'un niveau, dans le rond de l'accueil enseignant.
class Entities::Classroom::LevelShortNameTest < ActiveSupport::TestCase
  test "the short name of each level of the programme, followed by its series" do
    { [ "6ème", nil ] => "6e", [ "3ème", nil ] => "3e", [ "2nde", "A" ] => "2de A", [ "1ère", "D" ] => "1re D",
      [ "Tle", "D" ] => "Tle D", [ "Tle", nil ] => "Tle" }.each do |(level, series), short|
      assert_equal short, Entities::Classroom::LevelShortName.for(level:, series:)
    end
  end

  test "an unknown level name is kept as it is" do
    assert_equal "CP2 B", Entities::Classroom::LevelShortName.for(level: "CP2", series: "B")
  end
end
