require "test_helper"

module Queries
  module Catalog
    class MaterialsQueryTest < ActiveSupport::TestCase
      test "les matières par nom, avec leur catégorie, leurs cours et leurs enseignants" do
        svt = create_material(name: "SVT", shortname: "SVT", category: "science")
        french = create_material(name: "Français", shortname: "Fr", category: "literature")
        create_material(name: "Anglais", shortname: "Ang", category: "other")
        2.times { create_course(material: svt) }
        create_teacher(material: svt)
        create_teacher(material: french)

        rows = MaterialsQuery.new.call

        assert_equal %w[Anglais Français SVT], rows.map(&:name)
        assert_equal MaterialsQuery::Row.new(slug: "svt", name: "SVT", shortname: "SVT", category: "science", courses_count: 2,
                                             teachers_count: 1), rows.last
        assert_equal [ "francais", "literature", 0, 1 ], rows.second.to_h.values_at(:slug, :category, :courses_count, :teachers_count)
        assert_equal [ 0, 0 ], rows.first.to_h.values_at(:courses_count, :teachers_count)
      end

      test "aucune matière : liste vide" do
        assert_empty MaterialsQuery.new.call
      end

      test "find : une matière par son slug, ou nil" do
        create_material(name: "Philosophie", shortname: "Philo", category: "literature")

        assert_equal [ "Philosophie", "Philo", "literature" ], MaterialsQuery.new.find(slug: "philosophie").to_h.values_at(:name, :shortname, :category)
        assert_nil MaterialsQuery.new.find(slug: "latin")
      end
    end
  end
end
