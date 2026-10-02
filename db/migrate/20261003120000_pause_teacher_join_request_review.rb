# ADR-0073: teacher validation is paused. A request made without a school code is approved at once, by no one, through the
# "auto" way. The requests still pending are approved the same way, and their teachers attached to their school as their
# primary one; a teacher who already has a primary school keeps it. Refused requests stay refused.
class PauseTeacherJoinRequestReview < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :school_join_requests, name: "school_join_requests_decided_via_values"
    add_check_constraint :school_join_requests, "decided_via IN ('team', 'sponsor', 'auto')",
                         name: "school_join_requests_decided_via_values"

    execute <<~SQL.squish
      INSERT INTO teacher_schools (teacher_id, school_id, "primary", created_at)
      SELECT r.teacher_id, r.school_id, TRUE, NOW()
      FROM school_join_requests r
      WHERE r.status = 'pending'
        AND NOT EXISTS (SELECT 1 FROM teacher_schools ts WHERE ts.teacher_id = r.teacher_id AND ts."primary")
      ON CONFLICT DO NOTHING
    SQL
    execute <<~SQL.squish
      UPDATE school_join_requests
      SET status = 'approved', decided_via = 'auto', decided_at = NOW(), updated_at = NOW()
      WHERE status = 'pending'
    SQL
  end

  # Approvals and attachments stay: only the former ways come back, which a request approved through "auto" refuses.
  def down
    remove_check_constraint :school_join_requests, name: "school_join_requests_decided_via_values"
    add_check_constraint :school_join_requests, "decided_via IN ('team', 'sponsor')", name: "school_join_requests_decided_via_values"
  end
end
