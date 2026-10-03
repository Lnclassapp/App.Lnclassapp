# 🔌 INFRA · Queries::Communication::SitemapQuery
# Rôle : articles publiés du plan du site (slug, updated_at pour lastmod), jamais un brouillon ni un archivé
# ADR  : 0074 (§4.6) · PRD blog : BL-05, BL-19
module Queries
  module Communication
    class SitemapQuery
      Row = Data.define(:slug, :updated_at)

      # → [Row], publication la plus récente d'abord : l'index partiel (published_at DESC, id DESC) WHERE status = 'published'.
      def call
        Orm::Article.where(status: "published").order(published_at: :desc, id: :desc)
                    .pluck(:slug, :updated_at).map { |slug, updated_at| Row.new(slug:, updated_at:) }
      end
    end
  end
end
