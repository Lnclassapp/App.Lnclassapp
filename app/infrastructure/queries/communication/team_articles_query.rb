# 🔌 INFRA · Queries::Communication::TeamArticlesQuery
# Rôle : liste de gestion du blog : tous les articles, du plus récemment modifié, 20 par page, auteur réel et lectures
# ADR  : 0026, 0073 · UDR : 0065
module Queries
  module Communication
    class TeamArticlesQuery
      PER_PAGE = 20
      Row = Data.define(:public_id, :slug, :title, :status, :signature, :author_name, :published_at, :archived_at,
                        :updated_at, :reads_count)
      Page = Data.define(:rows, :total_count, :page, :pages)

      # UDR-0065 §3.2 : l'équipe lit le nom réel de l'auteur, quelle que soit la signature ; seules les pages publiques
      # appliquent le repli « L'équipe Lnclass » (BL-18).
      COLUMNS = [
        "articles.public_id", "articles.slug", "articles.title", "articles.status", "articles.signature",
        Arel.sql("users.first_name || ' ' || users.last_name"), "articles.published_at", "articles.archived_at",
        "articles.updated_at", "articles.reads_count"
      ].freeze

      def call(page: 1)
        scope = Orm::Article.joins(:author)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 ou page[a]=1 donnent un tableau ou un hash
        rows = scope.order(updated_at: :desc, id: :desc).offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*COLUMNS)
        Page.new(rows: rows.map { |values| Row.new(*values) }, total_count:, page:, pages:)
      end

      # Une ligne relue après une transition ou une publication refusée. → Row | nil
      def find(public_id:)
        values = Orm::Article.joins(:author).where(public_id:).pick(*COLUMNS)
        values && Row.new(*values)
      end
    end
  end
end
