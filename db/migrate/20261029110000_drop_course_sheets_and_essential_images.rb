# ADR-XXXX §4.3 et §4.5 (refonte-contenus-maths, Lot R) : la fiche cahier, les images de notions, le texte riche des notions et les
# types de rapport « fiche de cours » et « notions » n'existent plus. Pas de reprise de données : la base est remise à zéro.
class DropCourseSheetsAndEssentialImages < ActiveRecord::Migration[8.1]
  KINDS = %w[schools course_tree exercises classrooms drenas school_codes classroom_links].freeze

  def up
    # Les pièces jointes et les fichiers des images partent avec leurs lignes (les octets du service de stockage ne sont pas lus ici).
    execute "CREATE TEMP TABLE retired_blobs ON COMMIT DROP AS SELECT blob_id AS id FROM active_storage_attachments WHERE record_type = 'Orm::EssentialImage'"
    execute "DELETE FROM active_storage_attachments WHERE record_type = 'Orm::EssentialImage'"
    execute "DELETE FROM active_storage_variant_records WHERE blob_id IN (SELECT id FROM retired_blobs)"
    execute "DELETE FROM active_storage_blobs WHERE id IN (SELECT id FROM retired_blobs)"
    execute "DELETE FROM action_text_rich_texts WHERE record_type = 'Orm::Essential'"
    drop_table :essential_images
    drop_table :course_sheets

    execute "DELETE FROM import_reports WHERE kind IN ('essentials', 'course_sheet')"
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN (#{KINDS.map { "'#{it}'" }.join(',')})", name: "import_reports_kind_values"

    change_column_null :essentials, :sheet, false, {}
    change_column_default :essentials, :sheet, from: nil, to: {}
    remove_check_constraint :essentials, name: "essentials_sheet_object"
    add_check_constraint :essentials, "jsonb_typeof(sheet) = 'object'", name: "essentials_sheet_object"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "les fiches cahier et les images de notions ne se reprennent pas"
  end
end
