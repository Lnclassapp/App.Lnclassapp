require "test_helper"

# ADR-0058: the barème in base, one entry per school type, level and series (nil on the first cycle).
module Repositories
  module Classroom
    class ClassroomPlanRepositoryTest < ActiveSupport::TestCase
      Entry = Entities::Classroom::ClassroomPlan::Entry
      NOW = Time.utc(2026, 9, 28, 12)

      setup do
        @repository = ClassroomPlanRepository.new
        @sixth = create_level(name: "6ème", position: 1, cycle: "first")
        @tle = create_level(name: "Tle", position: 7)
        @d = create_series(name: "D")
        link_level_series(level: @tle, series: @d)
      end

      def entry(school_type, level, series, count) = Entry.new(school_type:, level_id: level.id, series_id: series&.id, count:)

      test "an empty barème" do
        assert_empty @repository.plan.entries
      end

      test "save inserts new entries, then replaces the count of the same keys, and plan reads them back" do
        assert @repository.save(entries: [ entry("public", @sixth, nil, 4), entry("private", @sixth, nil, 2),
                                           entry("public", @tle, @d, 6) ], at: NOW)
        @repository.save(entries: [ entry("public", @sixth, nil, 5), entry("private", @tle, @d, 0) ], at: NOW + 60)

        plan = @repository.plan
        assert_equal [ 5, 2, 6, 0 ], [ plan.count(school_type: "public", level_id: @sixth.id),
                                       plan.count(school_type: "private", level_id: @sixth.id),
                                       plan.count(school_type: "public", level_id: @tle.id, series_id: @d.id),
                                       plan.count(school_type: "private", level_id: @tle.id, series_id: @d.id) ]
        assert_equal 4, Orm::ClassroomPlanEntry.count
        record = Orm::ClassroomPlanEntry.find_by!(school_type: "public", level: @sixth)
        assert_equal [ NOW, NOW + 60 ], [ record.created_at, record.updated_at ]
      end

      test "saving nothing writes nothing" do
        assert @repository.save(entries: [], at: NOW)
        assert_equal 0, Orm::ClassroomPlanEntry.count
      end

      test "the base refuses a count out of 0 to 30, an unknown type, and a second entry of the same key" do
        insert = ->(**attributes) { Orm::ClassroomPlanEntry.create!(school_type: "public", level: @sixth, count: 1, **attributes) }

        assert_raises(ActiveRecord::StatementInvalid) { Orm::ClassroomPlanEntry.transaction(requires_new: true) { insert.call(count: 31) } }
        assert_raises(ActiveRecord::StatementInvalid) { Orm::ClassroomPlanEntry.transaction(requires_new: true) { insert.call(count: -1) } }
        assert_raises(ActiveRecord::StatementInvalid) { Orm::ClassroomPlanEntry.transaction(requires_new: true) { insert.call(school_type: "mixed") } }
        insert.call
        assert_raises(ActiveRecord::RecordNotUnique) { Orm::ClassroomPlanEntry.transaction(requires_new: true) { insert.call } }
        insert.call(series: @d)
        assert_raises(ActiveRecord::RecordNotUnique) { Orm::ClassroomPlanEntry.transaction(requires_new: true) { insert.call(series: @d) } }
      end

      test "the entries follow the referential: a deleted level or series takes its entries away, never refused for them" do
        @repository.save(entries: [ entry("public", @sixth, nil, 4), entry("public", @tle, @d, 6) ], at: NOW)
        taxonomy = Repositories::Catalog::TaxonomyRepository.new

        assert taxonomy.delete_level(id: @sixth.id).success?
        taxonomy.unlink(level_id: @tle.id, series_id: @d.id)
        assert_equal 1, Orm::ClassroomPlanEntry.count
        assert taxonomy.delete_series(id: @d.id).success?

        assert_equal 0, Orm::ClassroomPlanEntry.count
      end
    end
  end
end
