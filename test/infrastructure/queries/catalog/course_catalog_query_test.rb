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
      def catalog(role, **filters) = CourseCatalogQuery.new.call(actor: actor(role), **filters)

      test "un élève, un enseignant ou un personnel d'établissement ne lit que les cours publiés, par matière, niveau et nom" do
        %i[student teacher school_admin].each do |role|
          assert_equal [ @conscience, @cellule, @genetique ].map(&:slug), catalog(role).map(&:slug), role
        end
      end

      test "chaque ligne porte ce que montre la carte : matière et sa catégorie, niveau, série, sous-titre, statut" do
        row = catalog(:student).last

        assert_equal [ @genetique.slug, "Génétique et évolution", "Du gène à l'espèce", "Tle", "D", "SVT", "science", "published" ],
                     row.to_h.values_at(:slug, :name, :subtitle, :level_name, :series_name, :material_name,
                                        :material_category, :status)
        assert_nil catalog(:student).first.series_name
      end

      test "l'équipe voit aussi les brouillons et les archivés, avec leur statut" do
        rows = catalog(:team)

        assert_equal [ @conscience, @cellule, @archive, @brouillon, @genetique ].map(&:slug), rows.map(&:slug)
        assert_equal %w[published published archived draft published], rows.map(&:status)
      end

      test "le filtre par matière et le filtre par niveau se combinent, par slug" do
        assert_equal [ @cellule, @genetique ].map(&:slug), catalog(:student, material: @svt.slug).map(&:slug)
        assert_equal [ @conscience, @genetique ].map(&:slug), catalog(:student, level: @tle.slug).map(&:slug)
        assert_equal [ @genetique.slug ], catalog(:student, level: @tle.slug, material: @svt.slug).map(&:slug)
      end

      test "un filtre vide est ignoré ; un slug inconnu ne donne aucun cours" do
        assert_equal 3, catalog(:student, level: "", material: nil).size
        assert_empty catalog(:student, material: "inconnue")
      end

      test "une seule requête, quel que soit le nombre de cours" do
        queries = count_queries { catalog(:team, level: @tle.slug) }

        assert_equal 1, queries
      end

      private

      def count_queries(&)
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
        count
      end
    end
  end
end
