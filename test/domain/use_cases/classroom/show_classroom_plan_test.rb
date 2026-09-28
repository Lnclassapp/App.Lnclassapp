require "test_helper"
require_relative "../../../support/domain/taxonomy_fixture"
require_relative "../../../support/domain/fake_classroom_plan"

# BC-01, BC-08, ADR-0058: the team reads the barème as the screen shows it: lines of the referential, counts, totals.
module UseCases
  module Classroom
    class ShowClassroomPlanTest < ActiveSupport::TestCase
      Fixture = Entities::Catalog::TaxonomyFixture

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def initialize(lookup) = @lookup = lookup
        def lookup = @lookup
      end

      def show(actor)
        ShowClassroomPlan.new(classroom_plan: FakeClassroomPlan.new(Fixture.plan), taxonomy: FakeTaxonomy.new(Fixture.lookup),
                              policy: Policies::Classroom::ManageClassroomPlanPolicy.new).call(actor:)
      end

      test "the team gets the sheet of the barème" do
        result = show(Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "field"))

        assert result.success?
        assert_equal 14, result.value.lines.size
        assert_equal({ "public" => { "first" => 28, "both" => 77 }, "private" => { "first" => 12, "both" => 38 } }, result.value.totals)
      end

      test "anyone else is refused" do
        assert_equal :forbidden, show(Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id: 1)).code
        assert_equal :forbidden, show(nil).code
      end
    end
  end
end
