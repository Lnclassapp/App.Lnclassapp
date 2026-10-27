# 🔌 INFRASTRUCTURE · Repositories::Catalog::CourseSheetRepository
# Rôle : traduit Orm::CourseSheet (document jsonb) ↔ Entities::Catalog::CourseSheet ; une fiche par leçon
# ADR  : 0110-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318)
module Repositories
  module Catalog
    class CourseSheetRepository
      include Ports::Catalog::CourseSheetRepositoryPort

      def find_by_course_id(course_id:)
        record = Orm::CourseSheet.find_by(course_id:)
        record && map_to_entity(record)
      end

      def exists_for_course?(course_id:)
        Orm::CourseSheet.exists?(course_id:)
      end

      # La fiche est revérifiée avant d'être écrite : un document hors contrat n'entre jamais, quel que soit l'appelant.
      def create(sheet:)
        return ::Shared::Result.failure(:invalid, errors: sheet.errors.to_hash) unless sheet.valid?

        record = Orm::CourseSheet.new(course_id: sheet.course_id, theme: sheet.theme, document: sheet.document,
                                      format_version: sheet.format_version)
        Orm::CourseSheet.transaction(requires_new: true) { record.save! }
        ::Shared::Result.success(map_to_entity(record))
      rescue ActiveRecord::RecordNotUnique
        ::Shared::Result.failure(:conflict, errors: { course_id: [ :taken ] })
      end

      private

      def map_to_entity(record)
        Entities::Catalog::CourseSheet.new(id: record.id, course_id: record.course_id, theme: record.theme, document: record.document,
                                           format_version: record.format_version, created_at: record.created_at)
      end
    end
  end
end
