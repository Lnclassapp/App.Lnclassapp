# ADR-0066: the DRENA become the fifth import kind, next to the classroom generation reports (ADR-0056).
class AddDrenasToImportReportKinds < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises','classrooms','drenas')",
                         name: "import_reports_kind_values"
  end

  def down
    execute "DELETE FROM import_reports WHERE kind = 'drenas'"
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises','classrooms')",
                         name: "import_reports_kind_values"
  end
end
