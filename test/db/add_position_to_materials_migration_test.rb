require "test_helper"
require Rails.root.join("db/migrate/20261015100100_add_position_to_materials").to_s

# ADR-0090 §4.2 : sur une base réelle, la migration range les matières du programme par slug, anciens slugs compris ;
# une autre matière reste sans rang. Chaque test tourne dans la transaction annulée du test.
class AddPositionToMaterialsMigrationTest < ActiveSupport::TestCase
  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { AddPositionToMaterials.new.migrate(direction) }
    end
    Orm::Material.reset_column_information
  end

  teardown { Orm::Material.reset_column_information }

  test "maths and mathematiques get 1, pc 2, hg 5, philo 7, another subject none" do
    names = { "Maths" => "MA", "Mathématiques" => "MAT", "PC" => "PC", "HG" => "HG", "Philo" => "PH", "Anglais" => "ANG" }
    names.each { |name, shortname| create_material(name:, shortname:, position: nil) }

    migrate(:down)
    migrate(:up)

    assert_equal({ "maths" => 1, "mathematiques" => 1, "pc" => 2, "hg" => 5, "philo" => 7, "anglais" => nil },
                 Orm::Material.pluck(:slug, :position).to_h)
  end

  test "the migration reruns both ways without failing" do
    migrate(:down)
    migrate(:down)
    assert_not_includes Orm::Material.column_names, "position"

    migrate(:up)
    migrate(:up)
    assert_includes Orm::Material.column_names, "position"
  end
end
