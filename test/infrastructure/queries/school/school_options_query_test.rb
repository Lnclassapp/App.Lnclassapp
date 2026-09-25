require "test_helper"

module Queries
  module School
    class SchoolOptionsQueryTest < ActiveSupport::TestCase
      setup { @query = SchoolOptionsQuery.new }

      test "les DRENA sont triées par nom" do
        yamoussoukro = create_drena(name: "Yamoussoukro")
        abidjan = create_drena(name: "Abidjan 2")

        assert_equal [ SchoolOptionsQuery::DrenaRow.new(public_id: abidjan.public_id, slug: abidjan.slug, name: "Abidjan 2"),
                       SchoolOptionsQuery::DrenaRow.new(public_id: yamoussoukro.public_id, slug: yamoussoukro.slug, name: "Yamoussoukro") ],
                     @query.drenas
      end

      test "les établissements d'une DRENA, actifs par défaut, triés par nom" do
        drena = create_drena
        lycee = create_school(drena:, name: "Lycée Moderne")
        college = create_school(drena:, name: "Collège Bellevue")
        inactive = create_school(drena:, name: "Collège Fermé", status: "inactive")
        create_school(name: "Ailleurs")

        assert_equal [ college.public_id, lycee.public_id ], @query.schools_for(drena_public_id: drena.public_id).map(&:public_id)
        assert_equal [ SchoolOptionsQuery::SchoolRow.new(public_id: inactive.public_id, name: "Collège Fermé") ],
                     @query.schools_for(drena_public_id: drena.public_id, status: "inactive")
      end
    end
  end
end
