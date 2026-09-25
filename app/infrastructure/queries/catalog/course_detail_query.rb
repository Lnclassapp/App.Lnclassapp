# 🔌 INFRA · Queries::Catalog::CourseDetailQuery
# Rôle : page d'un cours (CA-04) : badges, statut, contenu riche, fiches essentielles publiées (toutes pour l'équipe)
# ADR  : 0026, 0028, 0035 · UDR : 0013
module Queries
  module Catalog
    class CourseDetailQuery
      Row = Data.define(:course, :essentials)
      # content : l'ActionText::RichText du cours, rendu et assaini par Action Text dans la vue.
      CourseRow = Data.define(:slug, :name, :subtitle, :status, :level_name, :series_name, :material_name, :material_slug,
                              :material_category, :content) do
        # Le fait que juge ReadPublishedPolicy : un cours n'a pas de parent, sa chaîne est publiée s'il l'est.
        def readable_chain_published? = status == "published"
      end
      EssentialRow = Data.define(:slug, :name, :subtitle, :status, :exercises_count)

      # Colonnes des tables jointes, lues sur l'enregistrement du cours sous leur nom de ligne.
      JOINED_COLUMNS = { level_name: "levels.name", series_name: "series.name", material_name: "materials.name",
                         material_slug: "materials.slug", material_category: "materials.category" }.freeze

      # → Row | nil (slug inconnu). La lecture d'un brouillon est l'affaire de ReadPublishedPolicy, dans le contrôleur.
      # Un seul cours : pas de with_rich_text_content, que Bullet signale inutile ; le contenu coûte une requête.
      def call(slug:, actor:)
        record = Orm::Course.joins(:level, :material).left_joins(:series)
                            .select("courses.*", *JOINED_COLUMNS.map { |name, column| "#{column} AS #{name}" })
                            .find_by(slug:)
        return if record.nil?

        course = CourseRow.new(**record.slice(:slug, :name, :subtitle, :status, *JOINED_COLUMNS.keys).symbolize_keys,
                               content: record.content)
        Row.new(course:, essentials: essentials(record.id, all: actor.team?))
      end

      private

      # all : brouillons et archivés compris, fiches comme exercices (équipe).
      def essentials(course_id, all:)
        scope = Orm::Essential.where(course_id:)
        scope = scope.where(status: "published") unless all
        rows = scope.order(:position).pluck(:id, :slug, :name, :subtitle, :status)
        counts = exercises_count(rows.map(&:first), all:)
        rows.map { |id, *values| EssentialRow.new(*values, counts.fetch(id, 0)) }
      end

      def exercises_count(essential_ids, all:)
        scope = Orm::Exercise.where(essential_id: essential_ids)
        scope = scope.where(status: "published") unless all
        scope.group(:essential_id).count
      end
    end
  end
end
