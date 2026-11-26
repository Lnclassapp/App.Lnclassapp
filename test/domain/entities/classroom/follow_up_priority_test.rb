require "test_helper"

# accueil-enseignant-actions (UDR §3.1, CA-1) : une classe est à suivre si elle a des élèves et du retard ou un exercice en
# cours ; la plus urgente d'abord.
class Entities::Classroom::FollowUpPriorityTest < ActiveSupport::TestCase
  Priority = Entities::Classroom::FollowUpPriority

  test "a classroom with students and late students or active assignments is to follow" do
    assert Priority.to_follow?(students: 40, late_students: 38, active_assignments: 1)
    assert Priority.to_follow?(students: 12, late_students: 0, active_assignments: 4)
    assert Priority.to_follow?(students: 12, late_students: 2, active_assignments: 0)
  end

  test "an empty classroom, or one with nothing assigned, is not to follow" do
    assert_not Priority.to_follow?(students: 0, late_students: 0, active_assignments: 3)
    assert_not Priority.to_follow?(students: 20, late_students: 0, active_assignments: 0)
  end

  test "more late students first, then more active assignments, then the given order" do
    rows = [ [ "1ère D", 0, 4 ], [ "Tle D", 38, 1 ], [ "2de A", 3, 1 ], [ "6e 1", 0, 4 ], [ "5e 2", 0, 6 ] ]
    sorted = rows.each_with_index.sort_by { |(_, late, active), index| Priority.rank(late_students: late, active_assignments: active, position: index) }
    assert_equal [ "Tle D", "2de A", "5e 2", "1ère D", "6e 1" ], sorted.map { it.first.first }
  end
end
