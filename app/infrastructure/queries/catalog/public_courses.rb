# 🔌 INFRA · Queries::Catalog::PublicCourses
# Rôle : socle des pages publiques du catalogue : la seule portée lue (cours publiés), la carte, l'ordre, 6 cartes par matière, les séries visibles
# ADR  : 0099 (§4.1, §4.2), 0090 (§4.2, rang des matières) · UDR : 0113 (§3.3, §3.6), 0115 (§3.1)
module Queries
  module Catalog
    module PublicCourses
      # Ce qu'une page publique montre d'un cours : son nom et sa description, jamais son statut ni son contenu (§4.1).
      Card = Data.define(:slug, :name, :subtitle, :material_slug, :level_slug)
      Material = Data.define(:slug, :name, :category)
      # count : cours de la matière dans la portée ; cards : les PER_GROUP premiers, par nom.
      Group = Data.define(:material, :count, :cards)
      # common : la portée compte au moins un cours sans série (UDR-0115 §3.2).
      Groups = Data.define(:groups, :total_count, :common)

      # ADR-0090 §4.2 : les matières dans l'ordre du programme ; une matière sans rang vient après, par nom.
      MATERIAL_ORDER = [ Arel.sql("materials.position ASC NULLS LAST"), "materials.name" ].freeze
      PER_GROUP = 6

      RANKED_COLUMNS = [
        "courses.id", "courses.slug", "courses.name", "courses.subtitle", "materials.slug AS material_slug",
        "levels.slug AS level_slug", "materials.name AS material_name", "materials.category AS material_category",
        "materials.position AS material_position",
        "ROW_NUMBER() OVER (PARTITION BY courses.material_id ORDER BY courses.name, courses.id) AS material_rank",
        "COUNT(*) OVER (PARTITION BY courses.material_id) AS material_count",
        "BOOL_OR(courses.series_id IS NULL) OVER () AS common"
      ].freeze
      RANKED_ORDER = [ Arel.sql("ranked.material_position ASC NULLS LAST"), "ranked.material_name", "ranked.name", "ranked.id" ].freeze
      RANKED_PLUCK = %w[ranked.slug ranked.name ranked.subtitle ranked.material_slug ranked.level_slug ranked.material_name
                        ranked.material_category ranked.material_count ranked.common].freeze

      module_function

      # La seule portée lue par les pages publiques : jamais un brouillon ni un archivé, filtré en SQL (ADR-0099 §4.2).
      def scope = Orm::Course.joins(:level, :material).where(status: "published")

      # Au moins un cours publié : le lien « Les cours par niveau » du pied de la homepage (UDR-0113 §3.9).
      def any? = scope.exists?

      # relation : une restriction de `scope`. Une requête, sans requête par carte : les PER_GROUP premiers cours de chaque
      # matière et le nombre de cours de la matière, par fenêtres SQL (UDR-0113 §3.6). → Groups
      def groups_by_material(relation)
        rows = Orm::Course.unscoped.from(relation.select(*RANKED_COLUMNS), :ranked)
                          .where("ranked.material_rank <= ?", PER_GROUP).order(*RANKED_ORDER).pluck(*RANKED_PLUCK)
        groups = rows.chunk_while { |one, other| one[3] == other[3] }.map do |cards|
          _, _, _, slug, _, name, category, count, = cards.first
          Group.new(material: Material.new(slug:, name:, category:), count:, cards: cards.map { Card.new(*it.first(5)) })
        end
        Groups.new(groups:, total_count: groups.sum(&:count), common: rows.any? { it.last })
      end

      # Séries visibles d'un niveau : rattachées (level_series) et portant au moins un cours publié, propre ou commun (sans
      # série, la règle d'AudienceFilter). level_id : un niveau, nil pour tous. Une requête.
      # → [[level_slug, series_slug, series_name, lastmod]], par rang du niveau puis nom de la série
      def series_pairs(level_id: nil)
        published = scope.select("courses.level_id", "courses.series_id", "courses.updated_at")
        # Jointures écrites : la sous-requête joint déjà `levels`, Active Record renommerait la jointure d'association.
        pairs = Orm::LevelSeries.joins(
          "INNER JOIN levels ON levels.id = level_series.level_id", "INNER JOIN series ON series.id = level_series.series_id",
          "INNER JOIN (#{published.to_sql}) published ON published.level_id = level_series.level_id " \
          "AND (published.series_id = level_series.series_id OR published.series_id IS NULL)"
        )
        pairs = pairs.where(level_id:) if level_id
        pairs.group("levels.id", "series.id").order("levels.position", "series.name")
             .pluck("levels.slug", "series.slug", "series.name", Arel.sql("MAX(published.updated_at)"))
      end
    end
  end
end
