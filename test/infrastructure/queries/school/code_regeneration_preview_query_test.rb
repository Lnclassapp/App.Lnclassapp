require "test_helper"

# ADR-0096 §4.5, UDR-0104: the modal of a mass regeneration counts exactly what the job will change, and names its scope.
module Queries
  module School
    class CodeRegenerationPreviewQueryTest < ActiveSupport::TestCase
      setup do
        @query = CodeRegenerationPreviewQuery.new
        @abidjan = create_drena(name: "Abidjan 1")
        @lycee = create_school(drena: @abidjan, name: "Lycée Moderne de Cocody")
        @college = create_school(drena: @abidjan, name: "Collège Saint Paul", status: "draft")
        create_school(drena: create_drena(name: "Bouaké"), name: "Lycée de Bouaké")
        @year = current_school_year
        level = create_level
        create_classroom(school: @lycee, level:, name: "6e 1")
        create_classroom(school: @lycee, level:, name: "6e 2", status: "archived")
        create_classroom(school: @lycee, level:, name: "6e 3", school_year: current_school_year(on: 1.year.ago.to_date))
        create_classroom(school: @college, level:, name: "6e 1")
      end

      def selection(**) = Dtos::School::SchoolSelection.from(**)

      test "the school codes count the schools of the list, as the repository does, without any year" do
        preview = @query.call(target: "school_codes", selection: selection(drena: @abidjan.public_id), school_year: @year)

        assert_equal [ "school_codes", 2, nil ], [ preview.target, preview.count, preview.school_year ]
        assert_equal CodeRegenerationPreviewQuery::Scope.new(drena_name: "Abidjan 1", school_name: nil), preview.scope
        assert_equal Repositories::School::SchoolRepository.new.count_for_code_regeneration(
          selection: selection(status: "draft"), created_before: 1.minute.from_now
        ), @query.call(target: "school_codes", selection: selection(status: "draft"), school_year: nil).count
        assert_equal 3, @query.call(target: "school_codes", selection: selection, school_year: nil).count
      end

      test "the classroom links count the active classrooms, of the year or of every year" do
        assert_equal 2, @query.call(target: "classroom_links", selection: selection(drena: @abidjan.public_id), school_year: @year).count
        assert_equal 3, @query.call(target: "classroom_links", selection: selection(drena: @abidjan.public_id), school_year: nil).count
      end

      test "one school from its card names it, and replaces the DRENA" do
        preview = @query.call(target: "classroom_links", selection: selection(school: @lycee.public_id, drena: @abidjan.public_id),
                              school_year: @year)

        assert_equal [ 1, @year ], [ preview.count, preview.school_year ]
        assert_equal CodeRegenerationPreviewQuery::Scope.new(drena_name: nil, school_name: "Lycée Moderne de Cocody"), preview.scope
      end

      test "an unknown DRENA or school counts nothing and names nothing" do
        preview = @query.call(target: "school_codes", selection: selection(drena: "inconnue"), school_year: nil)

        assert_equal [ 0, nil, nil ], [ preview.count, preview.scope.drena_name, preview.scope.school_name ]
        assert_nil @query.scope(selection(school: "inconnu")).school_name
      end
    end
  end
end
