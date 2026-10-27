require "test_helper"

module Repositories
  module Catalog
    class CourseSheetRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = CourseSheetRepository.new
        @course = create_course
      end

      def sheet(course_id: @course.id, **attributes)
        Entities::Catalog::CourseSheet.new(course_id:, theme: "blue", document: course_sheet_document, format_version: 1, **attributes)
      end

      test "creates a sheet and reads it back by lesson" do
        created = @repository.create(sheet:).value

        found = @repository.find_by_course_id(course_id: @course.id)

        assert_instance_of Entities::Catalog::CourseSheet, found
        assert_equal [ created.id, @course.id, "blue", 1 ], [ found.id, found.course_id, found.theme, found.format_version ]
        assert_equal course_sheet_document, found.document
        assert_equal 3, found.pages.size
        assert found.created_at
      end

      test "knows whether a lesson has a sheet, and returns nil when it has none" do
        assert_not @repository.exists_for_course?(course_id: @course.id)
        assert_nil @repository.find_by_course_id(course_id: @course.id)

        @repository.create(sheet:)

        assert @repository.exists_for_course?(course_id: @course.id)
      end

      test "a second sheet for the same lesson is a conflict and the first stays" do
        @repository.create(sheet: sheet(theme: "teal"))

        result = @repository.create(sheet: sheet(theme: "burgundy"))

        assert_equal [ :conflict, { course_id: [ :taken ] } ], [ result.code, result.errors ]
        assert_equal "teal", @repository.find_by_course_id(course_id: @course.id).theme
      end

      test "an invalid sheet is refused and not written" do
        result = @repository.create(sheet: sheet(theme: "rose"))

        assert_equal :invalid, result.code
        assert_not @repository.exists_for_course?(course_id: @course.id)
      end
    end
  end
end
