require "test_helper"

module UseCases
  module Catalog
    class CreateCourseTest < ActiveSupport::TestCase
      Course = Entities::Catalog::Course

      # Comme l'index unique de la table : un nom par niveau, matière et série ; le slug est dérivé du nom.
      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        attr_reader :created

        def initialize(taken_names = [])
          @taken_names = taken_names
          @created = []
        end

        def create(course:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @taken_names.include?(course.name)

          course.id = 12
          course.slug = course.name.parameterize
          @created << course
          Shared::Result.success(course)
        end
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def lookup = Entities::Catalog::TaxonomyFixture.lookup
      end

      setup do
        @courses = FakeCourses.new([ "Optique" ])
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(actor: @team, **overrides)
        dto = Dtos::Catalog::CourseInput.new(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level_slug: "tle",
                                             series_slug: "d", material_slug: "physique-chimie",
                                             content: "<div><strong>ADN</strong></div>", **overrides)
        CreateCourse.new(courses: @courses, taxonomy: FakeTaxonomy.new, policy: Policies::Catalog::ManageContentPolicy.new)
                    .call(actor:, dto:)
      end

      test "l'équipe crée un cours en brouillon, dont elle est l'autrice, nom gardé sans changement de casse" do
        result = create(name: "génétique  et Évolution")

        assert result.success?
        course = @courses.created.sole
        assert_same course, result.value
        assert_equal [ "génétique et Évolution", "Du gène à l'espèce", "draft", 7 ],
                     [ course.name, course.subtitle, course.status, course.author_id ]
        assert_equal [ 7, 105, 201 ], [ course.level_id, course.series_id, course.material_id ]
        assert_equal "<div><strong>ADN</strong></div>", course.content
      end

      test "un cours sans série est permis" do
        assert_nil create(series_slug: "").value.series_id
      end

      test "hors de l'équipe : :forbidden, rien n'est écrit, avant même de lire la saisie" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, create(actor: teacher).code
        assert_equal :forbidden, create(actor: nil, name: "").code
        assert_empty @courses.created
      end

      test "une saisie invalide donne :invalid, avec les erreurs du formulaire" do
        result = create(name: "", material_slug: nil)

        assert_equal :invalid, result.code
        assert_equal %i[name material_slug], result.errors.keys
        assert_empty @courses.created
      end

      test "un niveau, une matière ou une série inconnus donnent :invalid sur leur champ" do
        result = create(level_slug: "7eme", material_slug: "latin", series_slug: "z")

        assert_equal :invalid, result.code
        assert_equal({ level_slug: [ :inclusion ], material_slug: [ :inclusion ], series_slug: [ :inclusion ] }, result.errors)
        assert_empty @courses.created
      end

      test "une série qui n'est pas ouverte au niveau donne :invalid" do
        assert_equal({ series_slug: [ :not_allowed ] }, create(level_slug: "2nde", series_slug: "d").errors)
        assert_equal({ series_slug: [ :not_allowed ] }, create(level_slug: "6eme", series_slug: "a").errors)
        assert_empty @courses.created
      end

      test "un niveau inconnu : la série n'est pas éprouvée contre un niveau absent" do
        assert_equal({ level_slug: [ :inclusion ] }, create(level_slug: "7eme").errors)
      end

      test "un nom déjà pris donne :conflict sur le nom" do
        result = create(name: "Optique")

        assert_equal :conflict, result.code
        assert_equal({ name: [ :taken ] }, result.errors)
      end
    end
  end
end
