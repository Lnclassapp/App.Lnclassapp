# 🔌 INFRA · Queries::Identity::TeacherMaterialsQuery
# Rôle : les matières d'enseignants dans un établissement, dans l'ordre d'ajout, en une requête pour toute une liste
# ADR  : 0094 (§10), 0103 (§4.3, §4.5) · UDR : 0126, 0127
module Queries
  module Identity
    class TeacherMaterialsQuery
      # Une matière à côté d'un nom : le nom seul quand il n'y en a qu'une, les noms courts au-delà (ADR-0103 §4.5).
      MaterialTag = Data.define(:id, :name, :shortname, :category, :slug)

      COLUMNS = %w[teacher_school_materials.teacher_id teacher_school_materials.school_id materials.id materials.name
                   materials.shortname materials.category materials.slug].freeze

      # Le libellé d'une liste : « Physique-Chimie » ; « PC, SVT » ; nil sans matière.
      def self.label(tags)
        return tags.first&.name if tags.size < 2

        tags.map(&:shortname).join(", ")
      end

      # pairs : [[teacher_id, school_id]] ; school_id nil : toutes ses listes, sans doublon (un enseignant sans
      # rattachement, une demande en attente). → { [teacher_id, school_id] => [MaterialTag] } ; une seule requête.
      def for_pairs(pairs)
        pairs = pairs.uniq
        teacher_ids = pairs.map(&:first).uniq
        return {} if teacher_ids.empty?

        rows = Orm::TeacherSchoolMaterial.joins(:material).where(teacher_id: teacher_ids).in_order.pluck(*COLUMNS)
        pairs.to_h do |teacher_id, school_id|
          own = rows.select { |row| row[0] == teacher_id && (school_id.nil? || row[1] == school_id) }
          [ [ teacher_id, school_id ], own.map { MaterialTag.new(*it.drop(2)) }.uniq(&:id) ]
        end
      end

      # → { teacher_id => [MaterialTag] } dans cet établissement ; [] pour un enseignant sans liste.
      def tags_for(teacher_ids:, school_id:)
        for_pairs(teacher_ids.map { [ it, school_id ] }).transform_keys(&:first)
      end
    end
  end
end
