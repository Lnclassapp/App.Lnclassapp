require "test_helper"
require Rails.root.join("script/perf/dataset").to_s

# ADR-0067: the measuring dataset (script/perf/dataset.rb) is seeded only under PERF=1, out of bin/ci. Its writers are
# played here on a small catalogue, in the transaction of the test, so that a schema change they no longer follow fails
# in CI rather than before the next recette.
class PerfDatasetTest < ActiveSupport::TestCase
  setup do
    create_team_member(contact: "0700000000", second_factor: false) # the content author and default assigner of the dataset
    level = create_level
    @classroom = create_classroom(level:)
    course = create_course(level:)
    @exercises = Array.new(2) { create_essential(course:) }.flat_map { |essential| Array.new(3) { create_exercise(essential:) } }
    @catalog = PerfDataset.catalog_index([ course.id ])
  end

  # ADR-0072, migration of 2026-10-03: only an exercise is assigned, the schema refuses anything else.
  test "the assignments are exercises of the classroom's catalogue, as the sessions expect them" do
    given = PerfDataset.seed_assignments([ @classroom.id ], {}, @catalog)

    assignments = Orm::ClassroomAssignment.where(classroom: @classroom)
    assert_equal [ "Exercise" ], assignments.distinct.pluck(:assignable_type)
    assert_empty assignments.pluck(:assignable_id) - @exercises.map(&:id)
    assert_equal assignments.pluck(:id, :assignable_id).sort, given.fetch(@classroom.id).map { |id, (exercise_id)| [ id, exercise_id ] }.sort
  end
end
