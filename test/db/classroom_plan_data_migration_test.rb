require "test_helper"
require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s

# BC-07, ADR-0058: the old barème (Entities::Classroom::DefaultClassroomPlan::PLAN until 2026-09-28) is taken over on
# the existing referential, by slug, so that production generates exactly the same classrooms after the deployment.
class ClassroomPlanDataMigrationTest < ActiveSupport::TestCase
  # The referential of the production: 6ème to Tle, A1, A2, C, D linked to 2nde, 1ère and Tle.
  setup do
    levels = [ [ "6ème", "first" ], [ "5ème", "first" ], [ "4ème", "first" ], [ "3ème", "first" ], [ "2nde", "second" ],
               [ "1ère", "second" ], [ "Tle", "second" ] ].each_with_index.to_h { |(name, cycle), index| [ name, create_level(name:, position: index + 1, cycle:) ] }
    series = %w[A1 A2 C D].to_h { [ it, create_series(name: it) ] }
    %w[2nde 1ère Tle].product(series.values).each { |level, item| link_level_series(level: levels[level], series: item) }
    @levels = levels
  end

  def migrate
    migration = FillClassroomPlanEntries.new
    migration.verbose = false
    migration.migrate(:up)
  end

  def total(school_type, cycle)
    Entities::Classroom::DefaultClassroomPlan.sheet(plan: Repositories::Classroom::ClassroomPlanRepository.new.plan,
                                                     lookup: Repositories::Catalog::TaxonomyRepository.new.lookup).totals.dig(school_type, cycle)
  end

  def counts(school_type)
    Orm::ClassroomPlanEntry.where(school_type:).joins(:level).left_joins(:series).order("levels.position", "series.name")
                           .pluck("levels.slug", "series.slug", :count)
  end

  test "the barème taken over gives 89, 44, 28 and 12, the numbers of the old constant" do
    migrate

    assert_equal [ 89, 44, 28, 12 ], [ total("public", "both"), total("private", "both"), total("public", "first"), total("private", "first") ]
  end

  test "one entry per level of the first cycle, per linked series in 2nde and 1ère, per named and linked series in Tle" do
    migrate

    assert_equal [ [ "6eme", nil, 4 ], [ "5eme", nil, 4 ], [ "4eme", nil, 10 ], [ "3eme", nil, 10 ],
                   [ "2nde", "a1", 6 ], [ "2nde", "a2", 6 ], [ "2nde", "c", 6 ], [ "2nde", "d", 6 ],
                   [ "1ere", "a1", 6 ], [ "1ere", "a2", 6 ], [ "1ere", "c", 6 ], [ "1ere", "d", 6 ],
                   [ "tle", "a1", 3 ], [ "tle", "a2", 2 ], [ "tle", "c", 2 ], [ "tle", "d", 6 ] ], counts("public")
    assert_equal [ 2, 2, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 1, 3 ], counts("private").map(&:last)
  end

  test "run twice, it writes nothing more and changes nothing the team has set" do
    migrate
    Orm::ClassroomPlanEntry.find_by!(school_type: "public", level: @levels["6ème"]).update!(count: 7)

    assert_no_difference("Orm::ClassroomPlanEntry.count") { migrate }
    assert_equal 7, Orm::ClassroomPlanEntry.find_by!(school_type: "public", level: @levels["6ème"]).count
  end

  test "a series of Tle outside the old list, or a pair not linked, stays undefined; an unknown level is ignored" do
    link_level_series(level: @levels["Tle"], series: create_series(name: "E"))
    Orm::LevelSeries.where(level: @levels["Tle"], series: Orm::Series.find_by!(slug: "c")).delete_all
    create_level(name: "Terminale Pro", position: 8)

    migrate

    assert_equal [ "a1", "a2", "d" ], Orm::ClassroomPlanEntry.where(school_type: "public", level: @levels["Tle"]).joins(:series).order("series.slug").pluck("series.slug")
    assert_equal 32 - 2, Orm::ClassroomPlanEntry.count
  end

  test "an empty referential gives an empty barème" do
    Orm::LevelSeries.delete_all
    Orm::Level.delete_all

    migrate

    assert_equal 0, Orm::ClassroomPlanEntry.count
  end
end
