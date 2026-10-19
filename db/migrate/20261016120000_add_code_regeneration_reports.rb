# ADR-0096: the mass regenerations of the school codes and of the classroom links are followed by reports without a file,
# hence without checksum; a classroom link change is dated, so that a job never changes again a link changed since its launch.
class AddCodeRegenerationReports < ActiveRecord::Migration[8.1]
  KINDS = %w[schools course_tree essentials exercises classrooms drenas].freeze
  WITHOUT_FILE = %w[classrooms school_codes classroom_links].freeze

  def up
    replace_kinds(KINDS + %w[school_codes classroom_links], without_file: WITHOUT_FILE)
    add_column :classrooms, :link_token_rotated_at, :datetime
  end

  def down
    remove_column :classrooms, :link_token_rotated_at
    execute "DELETE FROM import_reports WHERE kind IN ('school_codes', 'classroom_links')"
    replace_kinds(KINDS, without_file: %w[classrooms])
  end

  private

  def replace_kinds(kinds, without_file:)
    remove_check_constraint :import_reports, name: "import_reports_kind_values"
    add_check_constraint :import_reports, "kind IN (#{kinds.map { "'#{it}'" }.join(',')})", name: "import_reports_kind_values"
    remove_check_constraint :import_reports, name: "import_reports_checksum_unless_generation"
    add_check_constraint :import_reports, "kind IN (#{without_file.map { "'#{it}'" }.join(',')}) OR checksum_sha256 IS NOT NULL",
                         name: "import_reports_checksum_unless_generation"
  end
end
