# 🔌 INFRA · Queries::Catalog::CourseCatalogQuery
# Rôle : cartes du catalogue (CA-01), filtrées par niveau, série, matière et nom (FU-47), par page ; publiés hors équipe ; élève : son niveau, groupé par matière dans l'ordre du programme, avec son avancement ; enseignant : ses matières à ses niveaux, chaque carte avec ses fiches de révision
# ADR  : 0026, 0028, 0035, 0076, 0090, 0103 · UDR : 0013 (amendement du 2026-10-05), 0054, 0069, 0077 §3.2, 0085, 0126 §3.1, XXXX écrans enseignant sans répétition §3.7
module Queries
  module Catalog
    class CourseCatalogQuery
      # Chantier cours-eleve (ADR-0090, UDR-0085) : material_slug et material_position groupent les cartes de l'élève ;
      # progress (:new, :started, :done) et resume_essential_slug (la fiche de « Reprendre », nil sinon) disent où il en est.
      # Hors élève : :new et nil. essentials : les fiches de révision publiées du cours ([EssentialLink], par position), pour
      # l'enseignant seulement (UDR enseignant §3.7) ; [] pour les autres rôles.
      Row = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category, :status,
                        :material_slug, :material_position, :progress, :resume_essential_slug, :essentials)
      EssentialLink = Data.define(:slug, :name)
      # Chantier politique-cache, lot E4 (UDR-0013, amendement du 2026-10-05) : le catalogue se lit par pages de PER_PAGE
      # cartes, les suivantes chargées au défilement. 24 tient en lignes pleines sur 1, 2 ou 3 colonnes.
      PER_PAGE = 24
      # material_counts : { slug de matière => nombre de cours } sur toute la recherche, pas seulement la page (titres des
      # groupes de l'élève, UDR-0085 §3.2, et de l'enseignant de plusieurs matières, UDR-0126 §3.1) ; {} sinon.
      Page = Data.define(:rows, :total_count, :page, :pages, :material_counts)
      NEUTRAL = [ :new, nil ].freeze

      COLUMNS = %w[courses.slug courses.name courses.subtitle levels.name series.name materials.name materials.category
                   courses.status materials.slug materials.position].freeze
      # ADR-0090 §4.2 : l'élève lit les matières dans l'ordre du programme ; une matière sans rang vient après, par nom.
      PROGRAM_ORDER = [ Arel.sql("materials.position ASC NULLS LAST"), "materials.name", "courses.name", "courses.id" ].freeze
      CATALOG_ORDER = [ "materials.name", "levels.position", "courses.name", "courses.id" ].freeze
      # UDR enseignant §3.7 : la progression, dans l'ordre des leçons (« Leçon 2 · Progression… » dans le sous-titre) ; un cours
      # sans numéro de leçon vient après, par nom.
      TEACHER_ORDER = [ "materials.name", "levels.position",
                        Arel.sql("(substring(courses.subtitle from '(?i)leçon\\s+(\\d+)'))::integer ASC NULLS LAST"),
                        "courses.name", "courses.id" ].freeze

      # level, material : slugs. Un filtre vide est ignoré, un slug inconnu ne donne aucun cours.
      # series : slug, appliqué seulement avec un niveau (UDR-0069 §3.4) : cours sans série et cours de cette série.
      # search : fragment du nom du cours, sans casse ni accents (UDR-0054 §3.9) ; vide, il est ignoré.
      # audience : Entities::Catalog::LevelAudience d'un élève (la règle de ReadOwnLevelPolicy) ou d'un enseignant (ses
      # classes, UDR-0077 §3.2) ; nil pour les autres rôles. material_ids : les matières de l'enseignant (ADR-0103) ; nil,
      # aucune restriction. group_by_material : l'enseignant de plusieurs matières, rangé comme l'élève (UDR-0126 §3.1).
      # page : entier, hors bornes ramené à la plus proche (une adresse forgée « page[]=2 » vaut 1).
      # Deux requêtes : le compte, puis les cartes de la page. L'élève : les comptes par matière (qui donnent le total), les
      # cartes, puis l'avancement des cours de la page (une requête, sans requête par carte). → Page
      def call(actor:, page: 1, group_by_material: false, **filters)
        scope = filtered(actor:, **filters)
        student_id = actor.user_id if actor.student?
        grouped = student_id || group_by_material
        material_counts = grouped ? scope.group("materials.slug").count : {}
        total_count = grouped ? material_counts.values.sum : scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages)
        rows = scope.order(*(grouped ? PROGRAM_ORDER : (actor.teacher? ? TEACHER_ORDER : CATALOG_ORDER))).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
                    .pluck("courses.id", *COLUMNS)
        progress = student_id ? progress_by_course(student_id, rows.map(&:first)) : {}
        essentials = actor.teacher? ? essentials_by_course(rows.map(&:first)) : {}
        rows = rows.map { |id, *values| Row.new(*values, *progress.fetch(id, NEUTRAL), essentials.fetch(id, [])) }
        Page.new(rows:, total_count:, page:, pages:, material_counts:)
      end

      private

      def filtered(actor:, level: nil, series: nil, material: nil, search: nil, audience: nil, material_ids: nil)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
        # La règle de ReadPublishedPolicy : l'équipe lit tout, les autres ne lisent que le publié.
        scope = scope.where(status: "published") unless actor.team?
        scope = scope.merge(AudienceFilter.courses(audience)) if audience
        scope = scope.where(material_id: material_ids) if material_ids
        if level.present?
          scope = scope.where(levels: { slug: level })
          scope = of_series(scope, series) if series.present?
        end
        scope = scope.where(materials: { slug: material }) if material.present?
        Queries::Shared::TextSearch.apply(scope, search, columns: [ "courses.name" ])
      end

      # La règle d'AudienceFilter, par slug : série vide ou cette série. Le cours sans série n'est gardé que si la série
      # existe, pour qu'une série inconnue ne donne aucun cours (dans la même requête).
      def of_series(scope, series)
        known = Orm::Series.where(slug: series).arel.exists
        scope.where(series: { slug: series }).or(scope.where(series_id: nil).where(known))
      end

      # UDR enseignant §3.7 : une requête pour les cours de la page — leurs fiches de révision publiées, par position.
      # → { course_id => [EssentialLink] }
      def essentials_by_course(course_ids)
        return {} if course_ids.empty?

        Orm::Essential.where(course_id: course_ids, status: "published").order(:position, :id).pluck(:course_id, :slug, :name)
                      .group_by(&:first).transform_values { |rows| rows.map { EssentialLink.new(*it.drop(1)) } }
      end

      # ADR-0090 §4.1 : une requête pour les cours de la page — leurs fiches publiées, lues ou non, et les fiches lues qui
      # ne le sont plus (pour savoir si la dernière ouverte a été dépubliée). → { course_id => [progress, resume_slug] }
      def progress_by_course(student_id, course_ids)
        return {} if course_ids.empty?

        reads = Orm::Essential.sanitize_sql_array(
          [ "LEFT JOIN essential_reads ON essential_reads.essential_id = essentials.id AND essential_reads.student_id = ?", student_id ]
        )
        Orm::Essential.joins(reads).where(course_id: course_ids)
                      .where("essentials.status = 'published' OR essential_reads.id IS NOT NULL")
                      .order(:position, :id).pluck(:course_id, :slug, :status, "essential_reads.last_read_at")
                      .group_by(&:first).transform_values { progress_of(it) }
      end

      # essentials : [course_id, slug, status, last_read_at], par position. :new sans fiche publiée lue ; :done quand toutes
      # les fiches publiées sont lues ; sinon :started, avec la dernière fiche ouverte si elle est encore publiée, à défaut
      # la première fiche publiée non lue (CA-10).
      def progress_of(essentials)
        published = essentials.select { |_, _, status| status == "published" }
        unread = published.reject(&:last)
        return NEUTRAL if unread.size == published.size
        return [ :done, nil ] if unread.empty?

        _, slug, status, = essentials.select(&:last).max_by(&:last)
        [ :started, status == "published" ? slug : unread.first[1] ]
      end
    end
  end
end
