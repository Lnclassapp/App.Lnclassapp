require "test_helper"

module Queries
  module Catalog
    # CA-01 : l'ancien catalogue ignorait ses filtres (clés String lues en Symbol) et cachait les brouillons même à
    # l'équipe. Ici, les filtres par slug s'appliquent, et l'équipe voit tous les statuts ; les autres, les publiés.
    class CourseCatalogQueryTest < ActiveSupport::TestCase
      setup do
        @tle = create_level(name: "Tle", position: 7)
        @seconde = create_level(name: "2nde", position: 5)
        @svt = create_material(name: "SVT", category: "science")
        @philo = create_material(name: "Philosophie", category: "literature")
        @genetique = create_course(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level: @tle,
                                   series: create_series(name: "D"), material: @svt)
        @cellule = create_course(name: "La cellule", level: @seconde, material: @svt)
        @conscience = create_course(name: "La conscience", level: @tle, material: @philo)
        @brouillon = create_course(name: "Brouillon", level: @tle, material: @svt, status: "draft")
        @archive = create_course(name: "Archivé", level: @tle, material: @svt, status: "archived")
      end

      def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:)
      def catalog(role, **filters) = CourseCatalogQuery.new.call(actor: actor(role), **filters).rows

      test "un enseignant ou un personnel d'établissement ne lit que les cours publiés, par nom de matière, niveau et nom" do
        %i[teacher school_admin].each do |role|
          assert_equal [ @conscience, @cellule, @genetique ].map(&:slug), catalog(role).map(&:slug), role
        end
      end

      # CA-1, CA-17 (ADR-0090 §4.2) : l'élève lit les publiés dans l'ordre du programme, materials.position (SVT 3,
      # Philosophie 7), puis le nom du cours ; le niveau ne départage plus.
      test "CA-1: un élève ne lit que les cours publiés, par rang de la matière, puis nom du cours" do
        assert_equal [ @genetique, @cellule, @conscience ].map(&:slug), catalog(:student).map(&:slug)
      end

      test "CA-17: une matière sans rang vient après les autres, par nom ; deux rangs égaux se départagent par nom" do
        anglais = create_course(name: "Anglais 1", level: @tle, material: create_material(name: "Anglais", position: nil))
        allemand = create_course(name: "Allemand 1", level: @tle, material: create_material(name: "Allemand", position: nil))
        histoire = create_course(name: "Z histoire", level: @tle, material: create_material(name: "Histoire", position: 3))

        assert_equal [ histoire, @genetique, @cellule, @conscience, allemand, anglais ].map(&:slug), catalog(:student).map(&:slug)
      end

      # Contrat gelé au Lot 0 (chantier cours-eleve) : hors élève, ni comptes par matière ni avancement.
      test "hors élève, chaque ligne porte sa matière et son rang, l'avancement neutre ; la page n'a pas de comptes" do
        page = CourseCatalogQuery.new.call(actor: actor(:teacher))
        row = page.rows.last

        assert_equal [ "svt", 3, :new, nil ], row.to_h.values_at(:material_slug, :material_position, :progress, :resume_essential_slug)
        assert_equal({}, page.material_counts)
        assert_equal 3, page.total_count
      end

      # UDR-0085 §3.2 : le titre d'un groupe compte toute la recherche, pas seulement la page.
      test "CA-15: les comptes par matière portent sur toute la recherche, et le total en est la somme" do
        26.times { |index| create_course(name: format("Cours %02d", index), level: @seconde, material: @svt) }
        first = CourseCatalogQuery.new.call(actor: actor(:student))

        assert_equal({ "svt" => 28, "philosophie" => 1 }, first.material_counts)
        assert_equal [ 29, 2, 24 ], [ first.total_count, first.pages, first.rows.size ]
        assert_equal({ "svt" => 1 }, CourseCatalogQuery.new.call(actor: actor(:student), search: "cellule").material_counts)
        assert_equal({}, CourseCatalogQuery.new.call(actor: actor(:student), search: "zzz").material_counts)
      end

      # CA-6 à CA-10 (ADR-0090 §4.1) : l'avancement de l'élève se lit sur les fiches publiées du cours.
      def progress_of(course, student) = student_catalog(student).find { it.slug == course.slug }.to_h.values_at(:progress, :resume_essential_slug)
      def student_catalog(student) = CourseCatalogQuery.new.call(actor: Entities::Identity::Actor.new(user_id: student.id, role: :student)).rows

      test "CA-6, CA-7, CA-8: rien lu, :new ; une fiche lue, :started et cette fiche ; toutes lues, :done" do
        student = create_student
        first = create_essential(course: @cellule, name: "La membrane")
        second = create_essential(course: @cellule, name: "Le noyau")
        create_essential(course: @cellule, name: "Brouillon", status: "draft")
        assert_equal [ :new, nil ], progress_of(@cellule, student)

        create_essential_read(student:, essential: second)
        assert_equal [ :started, second.slug ], progress_of(@cellule, student)

        create_essential_read(student:, essential: first, at: 1.hour.ago)
        assert_equal [ :done, nil ], progress_of(@cellule, student)
        assert_equal [ :new, nil ], progress_of(@cellule, create_student), "les lectures d'un autre élève ne comptent pas"
      end

      test "CA-7: « Reprendre » rouvre la fiche publiée lue en dernier" do
        student = create_student
        first = create_essential(course: @cellule)
        second = create_essential(course: @cellule)
        create_essential(course: @cellule)
        create_essential_read(student:, essential: second, at: 2.days.ago)
        create_essential_read(student:, essential: first, at: 1.hour.ago)

        assert_equal [ :started, first.slug ], progress_of(@cellule, student)
      end

      test "CA-9: une fiche publiée après que l'élève a tout lu le fait repasser à :started" do
        student = create_student
        read = create_essential(course: @cellule)
        create_essential_read(student:, essential: read)
        assert_equal :done, progress_of(@cellule, student).first

        create_essential(course: @cellule)
        assert_equal [ :started, read.slug ], progress_of(@cellule, student)
      end

      test "CA-10: la dernière fiche ouverte dépubliée, « Reprendre » ouvre la première fiche publiée non lue" do
        student = create_student
        first = create_essential(course: @cellule)
        unread = create_essential(course: @cellule)
        withdrawn = create_essential(course: @cellule)
        create_essential(course: @cellule)
        create_essential_read(student:, essential: first, at: 2.days.ago)
        create_essential_read(student:, essential: withdrawn, at: 1.hour.ago)
        withdrawn.update!(status: "archived", archived_at: Time.current)

        assert_equal [ :started, unread.slug ], progress_of(@cellule, student)
      end

      test "un cours sans fiche publiée reste :new ; seule la fiche dépubliée lue ne compte pas" do
        student = create_student
        withdrawn = create_essential(course: @cellule)
        create_essential_read(student:, essential: withdrawn)
        withdrawn.update!(status: "draft")

        assert_equal [ :new, nil ], progress_of(@cellule, student)
        assert_equal [ :new, nil ], progress_of(@genetique, student)
      end

      # PRD §7 : comptes par matière (qui donnent le total), cartes, avancement ; trois requêtes, sans requête par carte.
      test "l'élève : trois requêtes, quel que soit le nombre de cours et de lectures" do
        student = create_student
        6.times { |index| create_essential_read(student:, essential: create_essential(course: create_course(level: @tle, material: @svt, name: "C#{index}"))) }

        assert_equal 3, count_queries { student_catalog(student) }
        assert_equal 2, count_queries { CourseCatalogQuery.new.call(actor: actor(:student), search: "zzz") }
      end

      test "chaque ligne porte ce que montre la carte : matière et sa catégorie, niveau, série, sous-titre, statut" do
        row = catalog(:student).find { it.slug == @genetique.slug }

        assert_equal [ @genetique.slug, "Génétique et évolution", "Du gène à l'espèce", "Tle", "D", "SVT", "science", "published" ],
                     row.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                        :material_category, :status)
        assert_nil catalog(:student).find { it.slug == @cellule.slug }.series_name
      end

      test "l'équipe voit aussi les brouillons et les archivés, avec leur statut" do
        rows = catalog(:team)

        assert_equal [ @conscience, @cellule, @archive, @brouillon, @genetique ].map(&:slug), rows.map(&:slug)
        assert_equal %w[published published archived draft published], rows.map(&:status)
      end

      # CA-5 (UDR-0077 §3.2) : l'enseignant, sa matière seule, aux niveaux (et séries) de ses classes.
      test "material_ids restreint à ses matières ; avec l'audience d'un enseignant, ses matières à ses niveaux seulement" do
        assert_equal [ @cellule, @genetique ].map(&:slug), catalog(:teacher, material_ids: [ @svt.id ]).map(&:slug)

        audience = Entities::Catalog::LevelAudience.new(pairs: [ [ @tle.id, @genetique.series_id ] ])
        assert_equal [ @genetique.slug ], catalog(:teacher, audience:, material_ids: [ @svt.id ]).map(&:slug)
        assert_empty catalog(:teacher, audience: Entities::Catalog::LevelAudience.none, material_ids: [ @svt.id ])
      end

      # EPM-12 (UDR-0126 §3.1) : plusieurs matières, rangées par matière avec leurs comptes ; ?material= hors portée : rien.
      test "a teacher of two subjects: both, grouped by subject, counted by subject; a filter outside them gives nothing" do
        page = CourseCatalogQuery.new.call(actor: actor(:teacher), material_ids: [ @svt.id, @philo.id ], group_by_material: true)

        assert_equal 3, page.total_count
        assert_equal({ @svt.slug => 2, @philo.slug => 1 }, page.material_counts)
        assert_equal 2, page.rows.map(&:material_slug).chunk_while { _1 == _2 }.count, "une suite de cartes par matière"
        assert_empty catalog(:teacher, material_ids: [ @svt.id ], material: @philo.slug)
        assert_equal({}, CourseCatalogQuery.new.call(actor: actor(:teacher), material_ids: [ @svt.id ]).material_counts)
      end

      test "le filtre par matière et le filtre par niveau se combinent, par slug" do
        assert_equal [ @genetique, @cellule ].map(&:slug), catalog(:student, material: @svt.slug).map(&:slug)
        assert_equal [ @genetique, @conscience ].map(&:slug), catalog(:student, level: @tle.slug).map(&:slug)
        assert_equal [ @genetique.slug ], catalog(:student, level: @tle.slug, material: @svt.slug).map(&:slug)
      end

      test "un filtre vide est ignoré ; un slug inconnu ne donne aucun cours" do
        assert_equal 3, catalog(:student, level: "", material: nil).size
        assert_empty catalog(:student, material: "inconnue")
      end

      # FU-47 (UDR-0054 §3.9) : recherche par nom, sans casse ni accents, qui se combine aux filtres.
      test "la recherche trouve un cours par son nom sans casse ni accents, et se combine aux filtres" do
        maths = create_course(name: "Mathématiques 3e", level: @seconde, material: create_material(name: "Maths"))

        assert_equal [ maths.slug ], catalog(:student, search: "mathematiques").map(&:slug)
        assert_equal [ maths.slug ], catalog(:student, search: "  MATHÉ  ").map(&:slug)
        assert_equal [ @genetique.slug ], catalog(:student, search: "GENETIQUE").map(&:slug)
        assert_equal [ @cellule.slug ], catalog(:student, search: "cellule", material: @svt.slug).map(&:slug)
        assert_empty catalog(:student, search: "cellule", level: @tle.slug)
        assert_empty catalog(:student, search: "zzz")
      end

      test "la recherche ne porte que sur le nom, garde la règle de statut, et un terme vide la laisse de côté" do
        assert_empty catalog(:student, search: "gène à l'espèce")
        assert_empty catalog(:student, search: "Brouillon")
        assert_equal [ @brouillon.slug ], catalog(:team, search: "brouillon").map(&:slug)
        assert_equal 3, catalog(:student, search: "").size
        assert_equal 3, catalog(:student, search: nil).size
        assert_empty catalog(:student, search: "%")
      end

      # Lot E4 (politique-cache) : le compte, puis la page ; deux requêtes, quel que soit le nombre de cours.
      test "deux requêtes, quel que soit le nombre de cours" do
        queries = count_queries { catalog(:team, level: @tle.slug) }

        assert_equal 2, queries
      end

      # RE-15 (UDR-0069 §3.4) : la règle de l'élève (AudienceFilter), série vide ou cette série, appliquée au filtre.
      test "avec un niveau, la série garde les cours sans série et ceux de cette série ; une série inconnue n'en garde aucun" do
        mecanique = create_course(name: "Mécanique", level: @tle, material: @svt, series: create_series(name: "C"))
        create_course(name: "Ondes", level: @seconde, material: @svt, series: @genetique.series)

        assert_equal [ @conscience, @genetique ].map(&:slug), catalog(:teacher, level: @tle.slug, series: "d").map(&:slug)
        assert_equal [ @conscience, mecanique ].map(&:slug), catalog(:teacher, level: @tle.slug, series: "c").map(&:slug)
        assert_equal [ @genetique.slug ], catalog(:teacher, level: @tle.slug, series: "d", material: @svt.slug).map(&:slug)
        assert_equal [ @conscience, @genetique, mecanique ].map(&:slug), catalog(:teacher, level: @tle.slug, series: "").map(&:slug)
        assert_empty catalog(:teacher, level: @tle.slug, series: "inconnue")
        assert_equal 2, count_queries { catalog(:team, level: @tle.slug, series: "d") }
      end

      test "sans niveau, la série est ignorée" do
        create_course(name: "Mécanique", level: @tle, material: @svt, series: create_series(name: "C"))

        assert_equal 4, catalog(:teacher, series: "d").size
        assert_equal 4, catalog(:teacher, level: "", series: "inconnue").size
      end

      test "la série restreint l'audience d'un élève, sans jamais l'élargir" do
        create_course(name: "Mécanique", level: @tle, material: @svt, series: create_series(name: "C"))
        audience = Entities::Catalog::LevelAudience.new(pairs: [ [ @tle.id, @genetique.series_id ] ])

        assert_equal [ @conscience.slug ], catalog(:student, level: @tle.slug, series: "c", audience:).map(&:slug)
      end

      private

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end

      # UDR-0013, amendement du 2026-10-01 : l'audience d'un élève restreint le catalogue à son niveau.
      test "avec l'audience d'un élève de Tle D : Tle D et Tle sans série ; ni Tle C, ni un autre niveau ; sans classe, rien" do
        tle = create_level
        d = create_series
        c = create_series
        own = create_course(name: "Génétique", level: tle, series: d)
        common = create_course(name: "Philosophie", level: tle)
        create_course(name: "Mécanique", level: tle, series: c)
        create_course(name: "Seconde", level: create_level)
        student = Entities::Identity::Actor.new(user_id: 1, role: :student)
        query = CourseCatalogQuery.new

        rows = query.call(actor: student, audience: Entities::Catalog::LevelAudience.new(pairs: [ [ tle.id, d.id ] ])).rows

        assert_equal [ own.slug, common.slug ].sort, rows.map(&:slug).sort
        assert_empty query.call(actor: student, audience: Entities::Catalog::LevelAudience.none).rows
        # Sans audience (enseignant, direction), la requête ne restreint pas le niveau.
        assert_includes query.call(actor: student).rows.map(&:name), "Seconde"
      end

      # Lot E4 (politique-cache, UDR-0013 amendement du 2026-10-05) : des pages de 24 cartes, dans l'ordre du catalogue,
      # avec le compte total ; une page hors bornes ou forgée est ramenée à la plus proche.
      test "le catalogue se lit par pages de 24 cartes, dans le même ordre, avec le compte total" do
        26.times { |index| create_course(name: format("Cours %02d", index), level: @seconde, material: @svt) }
        query = CourseCatalogQuery.new
        first = query.call(actor: actor(:team))
        second = query.call(actor: actor(:team), page: 2)

        assert_equal [ 31, 31 ], [ first.total_count, second.total_count ], "5 cours de départ et 26 de plus, tous états"
        assert_equal [ 1, 2, 2 ], [ first.page, second.page, second.pages ]
        assert_equal [ 24, 7 ], [ first.rows.size, second.rows.size ]
        slugs = (first.rows + second.rows).map(&:slug)
        assert_equal Orm::Course.order(:id).pluck(:slug).sort, slugs.sort
        assert_equal 2, query.call(actor: actor(:team), page: "99").page
        assert_equal 1, query.call(actor: actor(:team), page: [ "2" ]).page
        assert_equal [ 1, 0 ], query.call(actor: actor(:team), material: "inconnue").then { [ it.pages, it.total_count ] }
      end
    end
  end
end
