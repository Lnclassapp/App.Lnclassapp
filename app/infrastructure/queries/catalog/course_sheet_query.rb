# 🔌 INFRA · Queries::Catalog::CourseSheetQuery
# Rôle : la fiche de cours d'une leçon (thème, pages, lexique) avec le nom et le statut de la leçon ; lecture seule
# ADR  : 0110-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318) · UDR : 0137-fiche-de-cours-a-l-identique-des-maquettes
module Queries
  module Catalog
    class CourseSheetQuery
      Row = Data.define(:course, :theme, :pages, :glossary) do
        # Le fait que juge ReadPublishedPolicy : la fiche se lit quand sa leçon est publiée.
        def readable_chain_published? = course.status == "published"
      end
      CourseRow = Data.define(:slug, :name, :status)

      # → Row | nil (leçon inconnue, ou sans fiche). Les pages et le lexique sont ceux du document stocké (clés en chaînes).
      # La lecture d'un brouillon est l'affaire de ReadPublishedPolicy, dans le contrôleur.
      def call(course_slug:)
        course_id, name, status = Orm::Course.where(slug: course_slug).pick(:id, :name, :status)
        return if course_id.nil?

        theme, document = Orm::CourseSheet.where(course_id:).pick(:theme, :document)
        return if theme.nil?

        Row.new(course: CourseRow.new(slug: course_slug, name:, status:), theme:, pages: document.fetch("pages", []),
                glossary: document.fetch("glossary", {}))
      end

      def exists?(course_slug:)
        Orm::CourseSheet.joins(:course).exists?(courses: { slug: course_slug })
      end
    end
  end
end
