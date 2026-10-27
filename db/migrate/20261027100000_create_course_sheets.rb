# ADR-0110 (contenu-en-blocs, #318) : la fiche de cours d'une leçon, un document de blocs en jsonb. Une par leçon ;
# une leçon qui a sa fiche ne se supprime pas (restrict, comme toute clé hors de la liste fermée des cascades).
# Le thème est une liste fermée, au schéma comme dans Entities::Catalog::CourseSheet.
class CreateCourseSheets < ActiveRecord::Migration[8.1]
  THEMES = %w[blue teal burgundy].freeze

  def change
    create_table :course_sheets do |t|
      t.references :course, null: false, foreign_key: { on_delete: :restrict }, index: { unique: true }
      t.string :theme, null: false
      t.jsonb :document, null: false
      t.integer :format_version, null: false, default: 1
      t.timestamps
      t.check_constraint "theme IN (#{THEMES.map { "'#{it}'" }.join(', ')})", name: "course_sheets_theme_values"
    end
  end
end
