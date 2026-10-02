# ADR-0073: teacher validation is paused. A request made without a school code is approved at once, by no one, through the
# "auto" way. The requests still pending are approved the same way when their teacher could have signed up today: an
# account that is not anonymized, an active school, no open withdrawal from it (ADR-0071). Their teachers are attached to
# the school as their primary one; a teacher who already has a primary school keeps it. Refused requests stay refused, the
# others stay pending. A teacher already linked to the school without being attached makes the migration fail rather
# than approve a request that attaches no one.
class PauseTeacherJoinRequestReview < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :school_join_requests, name: "school_join_requests_decided_via_values"
    add_check_constraint :school_join_requests, "decided_via IN ('team', 'sponsor', 'auto')",
                         name: "school_join_requests_decided_via_values"

    execute <<~SQL.squish
      WITH approved AS (
        UPDATE school_join_requests r
        SET status = 'approved', decided_via = 'auto', decided_at = NOW(), updated_at = NOW()
        FROM users u, schools s
        WHERE r.status = 'pending'
          AND u.id = r.teacher_id AND u.anonymized_at IS NULL
          AND s.id = r.school_id AND s.status = 'active'
          AND NOT EXISTS (SELECT 1 FROM teacher_school_departures d
                          WHERE d.teacher_id = r.teacher_id AND d.school_id = r.school_id AND d.reinstated_at IS NULL)
        RETURNING r.teacher_id, r.school_id
      )
      INSERT INTO teacher_schools (teacher_id, school_id, "primary", created_at)
      SELECT a.teacher_id, a.school_id, TRUE, NOW()
      FROM approved a
      WHERE NOT EXISTS (SELECT 1 FROM teacher_schools ts WHERE ts.teacher_id = a.teacher_id AND ts."primary")
    SQL
  end

  # Approvals and attachments stay: only the former ways come back, which a request approved through "auto" refuses.
  def down
    remove_check_constraint :school_join_requests, name: "school_join_requests_decided_via_values"
    add_check_constraint :school_join_requests, "decided_via IN ('team', 'sponsor')", name: "school_join_requests_decided_via_values"
  end
end
