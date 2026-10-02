# ADR-0072 §4.3: the due date is the next session day of the author, strictly after the local (Abidjan) date of the
# assignment, at most a week later. Written once by AssignResource, never recomputed. NULL without session days.
class AddDueOnToClassroomAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :classroom_assignments, :due_on, :date
    add_check_constraint :classroom_assignments,
                         "due_on IS NULL OR due_on - (assigned_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Abidjan')::date BETWEEN 1 AND 7",
                         name: "classroom_assignments_due_on_within_a_week"
  end
end
