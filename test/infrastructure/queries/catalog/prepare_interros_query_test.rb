require "test_helper"

module Queries
  module Catalog
    # Squelette du Lot 0 : le contrat gelé, rendu vide. Le Lot B le complète.
    class PrepareInterrosQueryTest < ActiveSupport::TestCase
      test "le contrat porte groups, lesson_wide et targets, et rend des listes vides tant que le Lot B n'est pas là" do
        assert_equal %i[groups lesson_wide targets], PrepareInterrosQuery::Prepare.members

        prepare = PrepareInterrosQuery.new.call(course_slug: create_course.slug, actor: nil)

        assert_equal [ [], [], [] ], [ prepare.groups, prepare.lesson_wide, prepare.targets ]
      end
    end
  end
end
