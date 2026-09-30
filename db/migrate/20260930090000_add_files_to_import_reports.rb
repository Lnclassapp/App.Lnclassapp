# ADR-0068: an import report keeps the list of its files and their own counts; its attachments become `sources`.
class AddFilesToImportReports < ActiveRecord::Migration[8.1]
  def up
    add_column :import_reports, :files, :jsonb, default: [], null: false
    execute <<~SQL
      UPDATE active_storage_attachments SET name = 'sources'
      WHERE record_type = 'Orm::ImportReport' AND name = 'source'
    SQL
    # One file per report until now: its line repeats the report counters, and a rejected report carries its first error.
    execute <<~SQL
      UPDATE import_reports r SET files = jsonb_build_array(jsonb_build_object(
        'name', b.filename, 'byte_size', b.byte_size,
        'status', CASE WHEN r.status = 'rejected' THEN 'rejected' WHEN r.status = 'completed' THEN 'read' ELSE 'pending' END,
        'reason', CASE WHEN r.status = 'rejected' AND jsonb_array_length(r.import_errors) > 0
                       THEN jsonb_build_object('code', r.import_errors->0->'code', 'params', COALESCE(r.import_errors->0->'params', '{}'::jsonb)) END,
        'imported', r.imported_count, 'skipped', r.skipped_count, 'errors', r.error_count))
      FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id = a.blob_id
      WHERE a.record_type = 'Orm::ImportReport' AND a.name = 'sources' AND a.record_id = r.id
    SQL
  end

  def down
    execute <<~SQL
      UPDATE active_storage_attachments SET name = 'source'
      WHERE record_type = 'Orm::ImportReport' AND name = 'sources'
    SQL
    remove_column :import_reports, :files
  end
end
