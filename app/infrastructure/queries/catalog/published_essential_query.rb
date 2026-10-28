# 🔌 INFRA · Queries::Catalog::PublishedEssentialQuery
# Rôle : la notion publiée d'une leçon publiée, lue sous sa leçon ; ne sert qu'à vérifier qu'une ancienne adresse de notion existe encore
# ADR  : 0028, 0035, 0113 (§4)
module Queries
  module Catalog
    class PublishedEssentialQuery
      # → le slug de la notion | nil (inconnue, en brouillon ou archivée, leçon non publiée, ou notion d'une autre leçon)
      def slug(course_slug:, essential_slug:)
        Orm::Essential.joins(:course).where(slug: essential_slug, status: "published", courses: { slug: course_slug, status: "published" })
                      .pick(:slug)
      end
    end
  end
end
