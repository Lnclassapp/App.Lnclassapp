# 🔌 INFRA · Repositories::Identity::TeacherMaterialRepository
# Rôle : lit, remplace et transmet les matières d'un enseignant dans un établissement (teacher_school_materials)
# ADR  : 0094 (§10), 0103 (§4.6 : écriture double retirée au Lot Z)
module Repositories
  module Identity
    class TeacherMaterialRepository
      include Ports::Identity::TeacherMaterialRepositoryPort

      def material_ids_for(teacher_id:, school_id:)
        Orm::TeacherSchoolMaterial.where(teacher_id:, school_id:).in_order.pluck(:material_id)
      end

      def replace(teacher_id:, school_id:, material_ids:, at:)
        rows = Orm::TeacherSchoolMaterial.where(teacher_id:, school_id:)
        rows.where.not(material_id: material_ids).delete_all
        kept = rows.pluck(:material_id)
        # Même instant pour les ajoutées : l'id, croissant dans l'ordre d'insertion, les départage (tri (created_at, id)).
        added = (material_ids - kept).map { |material_id| { teacher_id:, school_id:, material_id:, created_at: at } }
        Orm::TeacherSchoolMaterial.insert_all!(added) if added.any?
        true
      end

      def inherit(teacher_id:, school_id:, from_school_id:, at:)
        return true if Orm::TeacherSchoolMaterial.exists?(teacher_id:, school_id:)

        source = (from_school_id if Orm::TeacherSchoolMaterial.exists?(teacher_id:, school_id: from_school_id)) ||
                 Orm::TeacherSchoolMaterial.where(teacher_id:).order(created_at: :desc, id: :desc).pick(:school_id)
        ids = source ? material_ids_for(teacher_id:, school_id: source) : []
        Orm::TeacherSchoolMaterial.insert_all!(ids.map { |material_id| { teacher_id:, school_id:, material_id:, created_at: at } }) if ids.any?
        true
      end
    end
  end
end
