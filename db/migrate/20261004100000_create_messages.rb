# ADR-0045 §4, amended by ADR-0078 §4.1: an announcement is a short card of the team, a direction or a teacher. Every
# live message (scheduled or published) has an end date, at most 90 days after its publication; a withdrawal names
# its moderator.
class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.string :title, limit: 60, null: false
      t.string :body, limit: 140, null: false
      t.string :audience, null: false
      t.references :school, foreign_key: { on_delete: :restrict }, index: true
      t.string :status, null: false
      t.string :illustration, null: false
      t.datetime :published_at
      t.datetime :ends_at
      t.datetime :edited_at
      t.datetime :withdrawn_at
      t.references :withdrawn_by, foreign_key: { to_table: :users, on_delete: :restrict }, index: false
      t.timestamps
      t.index %i[status published_at]
      t.index %i[author_id created_at]
      t.check_constraint "audience IN ('all', 'students', 'teachers', 'school_admins', 'classrooms')", name: "messages_audience_values"
      t.check_constraint "status IN ('draft', 'scheduled', 'published', 'archived', 'withdrawn')", name: "messages_status_values"
      t.check_constraint "illustration IN ('info', 'calendar', 'homework', 'sheets', 'exam', 'meeting', 'celebration', 'holidays')",
                         name: "messages_illustration_values"
      t.check_constraint "btrim(title) <> ''", name: "messages_title_present"
      t.check_constraint "btrim(body) <> ''", name: "messages_body_present"
      t.check_constraint "status NOT IN ('scheduled', 'published') OR published_at IS NOT NULL", name: "messages_published_at_when_live"
      t.check_constraint "status NOT IN ('scheduled', 'published') OR ends_at IS NOT NULL", name: "messages_ends_at_when_live"
      t.check_constraint "ends_at IS NULL OR published_at IS NULL OR " \
                         "(ends_at > published_at AND ends_at <= published_at + interval '90 days')", name: "messages_ends_at_window"
      t.check_constraint "(status = 'withdrawn') = (withdrawn_at IS NOT NULL AND withdrawn_by_id IS NOT NULL)",
                         name: "messages_withdrawn_iff_withdrawal"
      t.check_constraint "audience <> 'classrooms' OR school_id IS NOT NULL", name: "messages_classrooms_need_school"
    end
  end
end
