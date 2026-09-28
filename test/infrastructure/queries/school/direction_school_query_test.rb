require "test_helper"

# ADR-0066 §4.6, UDR-0052 §3.7: the header of the « Établissement » page reads the school of the actor, and it alone.
module Queries
  module School
    class DirectionSchoolQueryTest < ActiveSupport::TestCase
      setup { @query = DirectionSchoolQuery.new }

      test "the school of the direction: name, DRENA, type, status and its code as shown" do
        school = create_school(name: "Lycée Moderne de Treichville", drena: create_drena(name: "Abidjan 2"), school_type: "mixed",
                               school_code: "k7m4qz")
        create_school(name: "Autre lycée")

        row = @query.call(school_id: school.id)

        assert_equal [ school.public_id, "Lycée Moderne de Treichville", "Abidjan 2", "mixed", "active", "k7m4qz" ],
                     row.to_h.values_at(:public_id, :name, :drena_name, :school_type, :status, :school_code)
        assert_equal "K7M-4QZ", row.school_code_display
      end

      test "no school is nil" do
        assert_nil @query.call(school_id: nil)
        assert_nil @query.call(school_id: 0)
      end
    end
  end
end
