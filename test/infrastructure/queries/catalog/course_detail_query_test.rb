require "test_helper"

module Queries
  module Catalog
    # CA-04, CA-10 : l'ancienne page ne filtrait rien, un brouillon se lisait par URL directe. La query lit le statut du
    # cours, que ReadPublishedPolicy juge dans le contrôleur, et ne rend les fiches non publiées qu'à l'équipe.
    class CourseDetailQueryTest < ActiveSupport::TestCase
      setup do
        @course = create_course(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level: create_level(name: "Tle"),
                                series: create_series(name: "D"), material: create_material(name: "SVT", category: "science"),
                                content: "<div><strong>ADN</strong> et $x^2$</div>")
        @meiose = create_essential(course: @course, name: "La méiose", subtitle: "Deux divisions")
        @brouillon = create_essential(course: @course, name: "Brouillon", status: "draft")
        @mitose = create_essential(course: @course, name: "La mitose")
        @archivee = create_essential(course: @course, name: "Archivée", status: "archived")
      end

      def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:)
      def detail(role, slug: @course.slug) = CourseDetailQuery.new.call(slug:, actor: actor(role))

      test "le cours, ses badges, son statut et son contenu riche" do
        course = detail(:student).course

        assert_equal [ @course.slug, "Génétique et évolution", "Du gène à l'espèce", "published", "Tle", "D", "SVT",
                       @course.material.slug, "science" ],
                     course.to_h.values_at(:slug, :name, :subtitle, :status, :level_name, :series_name, :material_name,
                                           :material_slug, :material_category)
        assert_includes course.content.body.to_html, "<strong>ADN</strong> et $x^2$"
      end

      test "le cours porte le fait que juge ReadPublishedPolicy : sa chaîne est publiée s'il l'est" do
        assert detail(:student).course.readable_chain_published?

        @course.update!(status: "draft")
        assert_not detail(:team).course.readable_chain_published?
        @course.update!(status: "archived")
        assert_not detail(:team).course.readable_chain_published?
      end

      test "un cours sans série, sans sous-titre ni contenu" do
        bare = create_course(content: nil)

        course = detail(:student, slug: bare.slug).course

        assert_nil course.series_name
        assert_nil course.subtitle
        assert_predicate course.content, :blank?
      end

      test "hors équipe, les fiches publiées dans l'ordre, chacune avec son nombre d'exercices publiés" do
        2.times { create_exercise(essential: @meiose) }
        create_exercise(essential: @meiose, status: "draft")
        create_exercise(essential: @mitose, status: "archived")

        %i[student teacher school_admin].each do |role|
          rows = detail(role).essentials

          assert_equal [ [ @meiose.slug, "La méiose", "Deux divisions", "published", 2 ], [ @mitose.slug, "La mitose", nil, "published", 0 ] ],
                       rows.map { it.to_h.values_at(:slug, :name, :subtitle, :status, :exercises_count) }, role
        end
      end

      test "l'équipe lit toutes les fiches, brouillons et archivées compris, et tous leurs exercices" do
        create_exercise(essential: @meiose)
        create_exercise(essential: @meiose, status: "draft")
        create_exercise(essential: @brouillon, status: "draft")

        rows = detail(:team).essentials

        assert_equal [ [ "La méiose", "published", 2 ], [ "Brouillon", "draft", 1 ], [ "La mitose", "published", 0 ],
                       [ "Archivée", "archived", 0 ] ],
                     rows.map { it.to_h.values_at(:name, :status, :exercises_count) }
      end

      test "un slug inconnu donne nil" do
        assert_nil detail(:team, slug: "inconnu")
      end
    end
  end
end
