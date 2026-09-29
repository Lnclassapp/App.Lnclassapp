# ADR-0056: the generation of the missing classrooms is followed by an import report of kind `classrooms`, which has
# no file, hence no checksum. Every other kind still requires one.
class AllowClassroomGenerationReports < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises','classrooms')",
                         name: "import_reports_kind_values"
    change_column_null :import_reports, :checksum_sha256, true
    add_check_constraint :import_reports, "kind = 'classrooms' OR checksum_sha256 IS NOT NULL",
                         name: "import_reports_checksum_unless_generation"
  end

  def down
    execute "DELETE FROM import_reports WHERE kind = 'classrooms'"
    remove_check_constraint :import_reports, name: "import_reports_checksum_unless_generation"
    change_column_null :import_reports, :checksum_sha256, false
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises')",
                         name: "import_reports_kind_values"
  end
end
