# ADR-0072 §4.1: only an exercise can be assigned. Grill Q7 says no course or essential assignment exists, archived ones
# included; if one does, stop here rather than lose it: nothing is changed and the deployment stops (ADR-0052). The check
# constraint stays the real guard: added under lock, it also refuses a row written between the count and its creation.
class RestrictClassroomAssignmentsToExercises < ActiveRecord::Migration[8.1]
  def up
    others = select_value("SELECT COUNT(*) FROM classroom_assignments WHERE assignable_type <> 'Exercise'").to_i
    if others.positive?
      raise ActiveRecord::MigrationError,
            "ADR-0072: #{others} course or essential assignment(s) found, archived ones included. " \
            "Nothing was changed; decide their fate in an ADR first."
    end

    remove_check_constraint :classroom_assignments, name: "classroom_assignments_type_values"
    add_check_constraint :classroom_assignments, "assignable_type = 'Exercise'", name: "classroom_assignments_type_values"
  end

  def down
    remove_check_constraint :classroom_assignments, name: "classroom_assignments_type_values"
    add_check_constraint :classroom_assignments, "assignable_type IN ('Course', 'Essential', 'Exercise')",
                         name: "classroom_assignments_type_values"
  end
end
