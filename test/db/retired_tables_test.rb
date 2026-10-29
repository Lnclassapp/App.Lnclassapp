require "test_helper"

# CA-17 (refonte-contenus-maths, Lot R) : ce que le chantier retire ne laisse rien dans la base.
class RetiredTablesTest < ActiveSupport::TestCase
  test "la table des fiches de cours et celle des images de notions n'existent plus" do
    connection = ActiveRecord::Base.connection

    assert_not connection.table_exists?("course_sheets")
    assert_not connection.table_exists?("essential_images")
  end

  test "les types de rapport « fiche de cours » et « notions » sont refusés par la base" do
    constraint = ActiveRecord::Base.connection.select_value(
      "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'import_reports_kind_values'"
    )

    assert_not_includes constraint, "course_sheet"
    assert_not_includes constraint, "'essentials'"
    assert_includes constraint, "course_tree"
  end

  test "les types d'import « fiche de cours » et « notions » n'existent plus" do
    assert_equal %w[schools course_tree drenas], Entities::Catalog::ImportKind::ALL.keys
    assert_not Entities::Catalog::ImportKind.valid?("course_sheet")
    assert_not Entities::Catalog::ImportKind.valid?("essentials")
  end

  test "une notion n'a plus de texte riche" do
    assert_not Orm::Essential.reflect_on_all_associations.map(&:name).include?(:rich_text_content)
    assert_not Orm::Essential.reflect_on_all_associations.map(&:name).include?(:images)
  end
end
