require "test_helper"

module Queries
  module School
    class DrenasQueryTest < ActiveSupport::TestCase
      setup { @query = DrenasQuery.new }

      test "aucune DRENA, aucune ligne" do
        assert_empty @query.call
      end

      test "les DRENA triées par nom, avec leurs établissements et leurs classes comptés" do
        yamoussoukro = create_drena(name: "Yamoussoukro")
        abidjan = create_drena(name: "Abidjan 1")
        lycee = create_school(drena: abidjan)
        create_school(drena: abidjan)
        2.times { create_classroom(school: lycee) }

        assert_equal [ DrenasQuery::Row.new(public_id: abidjan.public_id, slug: "drena-abidjan-1", name: "Abidjan 1",
                                            schools_count: 2, classrooms_count: 2),
                       DrenasQuery::Row.new(public_id: yamoussoukro.public_id, slug: "drena-yamoussoukro", name: "Yamoussoukro",
                                            schools_count: 0, classrooms_count: 0) ],
                     @query.call
      end

      test "une DRENA par son public_id, ou rien" do
        drena = create_drena(name: "Abidjan 1")
        create_classroom(school: create_school(drena:))
        create_drena(name: "Abidjan 2")

        assert_equal DrenasQuery::Row.new(public_id: drena.public_id, slug: "drena-abidjan-1", name: "Abidjan 1",
                                          schools_count: 1, classrooms_count: 1),
                     @query.find(public_id: drena.public_id)
        assert_nil @query.find(public_id: "inconnu")
        assert_nil @query.find(public_id: drena.id.to_s)
      end
    end
  end
end
