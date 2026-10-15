# ADR-0090 §4.2, chantier cours-eleve : le rang du programme, lu par « Mes matières », l'exercice du jour et la page
# Cours de l'élève ; il remplace la constante SUBJECT_ORDER. Rempli par slug (anciens slugs compris) ; une autre matière
# reste sans rang et vient après, par nom. Rejouable dans les deux sens.
class AddPositionToMaterials < ActiveRecord::Migration[8.1]
  PROGRAM = [ %w[mathematiques maths], %w[physique-chimie pc], %w[svt], %w[francais],
              %w[histoire-geographie histoire-geo hg], %w[edhc], %w[philosophie philo] ].freeze

  def up
    add_column :materials, :position, :integer, if_not_exists: true
    PROGRAM.each.with_index(1) do |slugs, position|
      execute <<~SQL.squish
        UPDATE materials SET position = #{position} WHERE slug IN (#{slugs.map { connection.quote(it) }.join(", ")})
      SQL
    end
  end

  def down
    remove_column :materials, :position, if_exists: true
  end
end
