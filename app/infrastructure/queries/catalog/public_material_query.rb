# 🔌 INFRA · Queries::Catalog::PublicMaterialQuery
# Rôle : page publique d'une matière (/matieres/:slug) : niveaux qui en ont un cours publié, filtre de niveau et de série, 24 cartes par page groupées par niveau
# ADR  : 0099 (§4.1, §4.2), 0076 · UDR : 0114 (§3.1, §3.3), 0013 (amendement du 2026-10-05 : pages chargées au défilement)
module Queries
  module Catalog
    class PublicMaterialQuery
      PER_PAGE = CourseCatalogQuery::PER_PAGE
      Named = Data.define(:slug, :name)
      # count : cours du niveau dans la matière (sans le filtre de série) ; cards : ceux de la page demandée.
      Group = Data.define(:level, :count, :cards)
      # levels : [[slug, name, count]] des niveaux qui ont au moins un cours publié de la matière, par rang ;
      # selected_level, selected_series : Named | nil ; groups : [Group] de la page, dans l'ordre des niveaux.
      Page = Data.define(:material, :levels, :selected_level, :selected_series, :groups, :total_count, :page, :pages)
      CARD_COLUMNS = %w[courses.slug courses.name courses.subtitle materials.slug levels.slug].freeze

      # slug : la matière ; level, series : slugs des filtres (?niveau=, ?serie=) ; page : entier, hors bornes ramené à la plus
      # proche. nil (404) : matière inconnue ; niveau inconnu ou sans cours de la matière ; série sans niveau, inconnue ou
      # non rattachée au niveau. Trois requêtes (la matière, les comptes par niveau, la page), une de plus avec une série.
      # → Page | nil
      def call(slug:, level: nil, series: nil, page: 1)
        material_id, *material = Orm::Material.where(slug:).pick(:id, :slug, :name, :category)
        return unless material_id

        scope = PublicCourses.scope.where(material_id:)
        counts = scope.group("levels.id").order("levels.position").pluck("levels.id", "levels.slug", "levels.name", Arel.sql("COUNT(*)"))
        scope, total_count, selected_level, selected_series = selection(scope, counts, level:, series:)
        return unless scope

        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages)
        cards = scope.order("levels.position", "courses.name", "courses.id").offset((page - 1) * PER_PAGE).limit(PER_PAGE)
                     .pluck(*CARD_COLUMNS).map { PublicCourses::Card.new(*it) }
        Page.new(material: PublicCourses::Material.new(*material), levels: counts.map { it[1..] }, selected_level:, selected_series:,
                 groups: groups(cards, counts), total_count:, page:, pages:)
      end

      private

      # → [scope, total_count, selected_level, selected_series] | nil. Une série sans niveau ne trouve aucun niveau.
      def selection(scope, counts, level:, series:)
        return [ scope, counts.sum(&:last), nil, nil ] unless level || series

        level_id, slug, name, count = counts.find { it[1] == level }
        return unless level_id

        scope = scope.where(level_id:)
        return [ scope, count, Named.new(slug:, name:), nil ] unless series

        # La règle d'AudienceFilter : les cours de la série et ceux sans série du niveau, comptés dans la même requête.
        count = scope.where("courses.series_id IS NULL OR courses.series_id = series.id").select("COUNT(*)")
        series_id, series_slug, series_name, total_count = Orm::LevelSeries.joins(:series).where(level_id:, series: { slug: series })
                                                                           .pick("series.id", "series.slug", "series.name", Arel.sql("(#{count.to_sql})"))
        return unless series_id

        [ scope.where(series_id: [ nil, series_id ]), total_count, Named.new(slug:, name:), Named.new(slug: series_slug, name: series_name) ]
      end

      # Les cartes de la page, par niveau ; le compte d'un groupe est celui du niveau dans la matière. Un niveau publié entre la
      # requête des comptes et celle des cartes n'y est pas : son groupe n'a ni nom ni compte, donc pas de titre (la page rend la grille).
      def groups(cards, counts)
        levels = counts.to_h { |_, slug, name, count| [ slug, [ Named.new(slug:, name:), count ] ] }
        cards.chunk_while { |one, other| one.level_slug == other.level_slug }.map do |chunk|
          level, count = levels.fetch(chunk.first.level_slug) { [ Named.new(slug: chunk.first.level_slug, name: nil), nil ] }
          Group.new(level:, count:, cards: chunk)
        end
      end
    end
  end
end
