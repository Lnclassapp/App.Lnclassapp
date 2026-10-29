# ADR-0116 §4.3 (refonte-contenus-maths, Lot 0) : la fiche de révision d'une notion, les figures et le thème d'une leçon, la figure
# d'un exercice. N'ajoute que : rien n'est retiré ici (le retrait des anciens contenus est le Lot R).
# essentials.sheet reste NULL-able tant que l'ancien texte riche existe ; le Lot R le passera en non nul avec le retrait de `content`.
class AddRevisionSheetToCatalog < ActiveRecord::Migration[8.1]
  THEMES = %w[blue teal burgundy].freeze

  def change
    add_column :essentials, :sheet, :jsonb
    add_check_constraint :essentials, "sheet IS NULL OR jsonb_typeof(sheet) = 'object'", name: "essentials_sheet_object"
    add_column :courses, :figures, :jsonb, null: false, default: []
    add_check_constraint :courses, "jsonb_typeof(figures) = 'array'", name: "courses_figures_array"
    add_column :courses, :sheet_theme, :string, null: false, default: "blue"
    add_check_constraint :courses, "sheet_theme IN (#{THEMES.map { "'#{it}'" }.join(', ')})", name: "courses_sheet_theme_known"
    add_column :exercises, :figure_key, :string
  end
end
