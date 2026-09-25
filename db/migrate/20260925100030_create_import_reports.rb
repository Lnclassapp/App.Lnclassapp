# ADR-0039 : persisted report of a bulk JSON import. The column is `import_errors`,
# because the ORM reserves `errors`. `format_version` is known once the envelope is read.
class CreateImportReports < ActiveRecord::Migration[8.1]
  def change
    create_table :import_reports do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.string :kind, null: false
      t.integer :format_version
      t.string :checksum_sha256, limit: 64, null: false
      t.string :status, null: false, default: "queued"
      t.integer :total_count, null: false, default: 0
      t.integer :processed_count, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :error_count, null: false, default: 0
      t.jsonb :details, null: false, default: {}
      t.jsonb :import_errors, null: false, default: []
      t.references :imported_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
      t.index :kind, unique: true, where: "status IN ('queued','validating','importing')",
                     name: "index_import_reports_one_running_per_kind"
      t.index [ :kind, :created_at ]
    end

    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises')",
                         name: "import_reports_kind_values"
    add_check_constraint :import_reports, "status IN ('queued','validating','importing','completed','rejected','failed')",
                         name: "import_reports_status_values"
    add_check_constraint :import_reports, "status <> 'completed' OR total_count = imported_count + skipped_count + error_count",
                         name: "import_reports_completed_counts_add_up"
  end
end
