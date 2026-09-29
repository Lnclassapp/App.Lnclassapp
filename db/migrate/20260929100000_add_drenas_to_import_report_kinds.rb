# ADR-0055 : the DRENA become the fifth import kind.
class AddDrenasToImportReportKinds < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises','drenas')",
                         name: "import_reports_kind_values"
  end

  def down
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN ('schools','course_tree','essentials','exercises')",
                         name: "import_reports_kind_values"
  end
end
