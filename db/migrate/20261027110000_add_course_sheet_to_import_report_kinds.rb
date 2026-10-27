# ADR-XXXX-fiche-de-cours-en-donnees-importees: the course sheet becomes an import kind, next to the essentials (ADR-0039).
class AddCourseSheetToImportReportKinds < ActiveRecord::Migration[8.1]
  KINDS = %w[schools course_tree essentials exercises classrooms drenas school_codes classroom_links].freeze

  def up
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN (#{(KINDS + %w[course_sheet]).map { "'#{it}'" }.join(',')})",
                         name: "import_reports_kind_values"
  end

  def down
    execute "DELETE FROM import_reports WHERE kind = 'course_sheet'"
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN (#{KINDS.map { "'#{it}'" }.join(',')})", name: "import_reports_kind_values"
  end
end
