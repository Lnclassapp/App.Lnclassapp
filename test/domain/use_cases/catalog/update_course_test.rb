require "test_helper"

module UseCases
  module Catalog
    class UpdateCourseTest < ActiveSupport::TestCase
      Course = Entities::Catalog::Course
      PUBLISHED_AT = Time.utc(2026, 9, 20, 8)
      # Identifiants du référentiel de TaxonomyFixture.
      TLE = 7
      SERIES_C = 104
      SERIES_D = 105

      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        attr_reader :updated, :level_reads

        # assigned : { course_id => [[level_id, series_id], ...] }, une paire par classe où un exercice du cours est assigné.
        def initialize(courses, assigned: {})
          @courses = courses
          @assigned = assigned
          @updated = []
          @level_reads = 0
        end

        def find_by_slug(slug:) = @courses.find { it.slug == slug }

        def assigned_classroom_levels(id:)
          @level_reads += 1
          @assigned.fetch(id, [])
        end

        def existing_keys
          @courses.to_set { [ Entities::Shared::NaturalKey.compact(it.name), it.level_id, it.material_id, it.series_id ] }
        end

        def update(course:)
          return Shared::Result.failure(:conflict, errors: { name: [ :taken ] }) if @courses.any? { it.name == course.name && it.id != course.id }

          @updated << course
          Shared::Result.success(course)
        end
      end

      class FakeTaxonomy
        include Ports::Catalog::TaxonomyRepositoryPort

        def lookup = Entities::Catalog::TaxonomyFixture.lookup
      end

      setup do
        @course = Course.new(id: 3, slug: "genetique", name: "Génétique", subtitle: "Ancien", level_id: 7, series_id: 105,
                             material_id: 201, author_id: 9, status: "published", published_at: PUBLISHED_AT, content: "<p>Ancien</p>")
        @courses = FakeCourses.new([ @course, Course.new(id: 4, slug: "optique", name: "Optique", level_id: 6, series_id: 104, material_id: 201) ])
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(slug: "genetique", actor: @team, **overrides)
        dto = Dtos::Catalog::CourseInput.new(name: "Génétique et évolution", subtitle: "", level_slug: "1ere", series_slug: "c",
                                             material_slug: "physique-chimie", content: "<div>Nouveau</div>", **overrides)
        UpdateCourse.new(courses: @courses, taxonomy: FakeTaxonomy.new, policy: Policies::Catalog::ManageContentPolicy.new)
                    .call(actor:, slug:, dto:)
      end

      test "modifier un cours change sa saisie ; slug, statut, auteur et dates restent" do
        result = update

        assert result.success?
        course = @courses.updated.sole
        assert_equal [ 3, "genetique", "published", 9, PUBLISHED_AT ],
                     [ course.id, course.slug, course.status, course.author_id, course.published_at ]
        assert_equal [ "Génétique et évolution", nil, "<div>Nouveau</div>" ], [ course.name, course.subtitle, course.content ]
        assert_equal [ 6, 104, 201 ], [ course.level_id, course.series_id, course.material_id ]
      end

      test "hors de l'équipe : :forbidden, sans rien lire ni écrire" do
        student = Entities::Identity::Actor.new(user_id: 5, role: :student)

        assert_equal :forbidden, update(actor: student).code
        assert_equal :forbidden, update(actor: nil, slug: "inconnu").code
        assert_empty @courses.updated
      end

      test "un cours inconnu donne :not_found" do
        assert_equal :not_found, update(slug: "inconnu").code
      end

      test "une saisie invalide donne :invalid" do
        result = update(name: " ")

        assert_equal :invalid, result.code
        assert_equal [ :name ], result.errors.keys
        assert_empty @courses.updated
      end

      test "une série non ouverte au niveau donne :invalid" do
        assert_equal({ series_slug: [ :not_allowed ] }, update(level_slug: "2nde", series_slug: "d").errors)
        assert_empty @courses.updated
      end

      test "le nom d'un autre cours donne :conflict" do
        assert_equal({ name: [ :taken ] }, update(name: "Optique").errors)
      end

      test "un nom qui ne diffère d'un autre cours que par la casse, les accents ou les espaces est pris" do
        assert_equal({ name: [ :taken ] }, update(name: " ÓP tique").errors)
        assert_empty @courses.updated
      end

      test "un cours peut changer la casse, les accents ou les espaces de son propre nom" do
        assert update(name: "GENETIQUE", level_slug: "tle", series_slug: "d").success?
      end

      # ADR-0075 / RE-27 : le cours de Tle D est assigné à des classes, une paire (niveau, série) par classe.
      def assigned_to(*pairs, course: @course)
        @courses = FakeCourses.new([ course ], assigned: { course.id => pairs })
      end

      test "RE-27 : changer le niveau ou la série d'un cours assigné hors de sa classe donne :conflict, sans rien écrire" do
        assigned_to([ TLE, SERIES_D ])

        [ { level_slug: "3eme", series_slug: "" }, { level_slug: "tle", series_slug: "c" }, {} ].each do |taxonomy|
          result = update(**taxonomy)

          assert_equal :conflict, result.code
          assert_equal({ level_slug: [ :assigned_elsewhere ] }, result.errors)
        end
        assert_empty @courses.updated
      end

      test "élargir un cours assigné de Tle D à Tle sans série est permis" do
        assigned_to([ TLE, SERIES_D ], [ TLE, SERIES_D ])

        result = update(level_slug: "tle", series_slug: "")

        assert result.success?
        assert_equal [ TLE, nil ], [ @courses.updated.sole.level_id, @courses.updated.sole.series_id ]
      end

      test "restreindre un cours de Tle à Tle D n'est refusé que s'il reste une classe assignée hors de la série D" do
        tle = Course.new(id: 5, slug: "philosophie", name: "Philosophie", level_id: TLE, series_id: nil, material_id: 201)
        restrict = -> { update(slug: "philosophie", name: "Philosophie", level_slug: "tle", series_slug: "d") }

        [ [ TLE, SERIES_C ], [ TLE, nil ] ].each do |outside|
          assigned_to([ TLE, SERIES_D ], outside, course: tle)

          assert_equal({ level_slug: [ :assigned_elsewhere ] }, restrict.call.errors)
          assert_empty @courses.updated
        end

        assigned_to([ TLE, SERIES_D ], course: tle)

        assert restrict.call.success?
        assert_equal [ TLE, SERIES_D ], [ @courses.updated.sole.level_id, @courses.updated.sole.series_id ]
      end

      test "le nom, le sous-titre et le contenu d'un cours assigné restent modifiables, sans lire ses classes" do
        assigned_to([ TLE, SERIES_D ])

        result = update(name: "Génétique humaine", subtitle: "Nouveau", level_slug: "tle", series_slug: "d")

        assert result.success?
        assert_equal [ "Génétique humaine", "Nouveau", TLE, SERIES_D ],
                     [ result.value.name, result.value.subtitle, result.value.level_id, result.value.series_id ]
        assert_equal 0, @courses.level_reads
      end

      test "sans assignation active (archivée ou jamais faite), le niveau d'un cours change librement" do
        assigned_to

        result = update(level_slug: "3eme", series_slug: "")

        assert result.success?
        assert_equal [ 4, nil ], [ result.value.level_id, result.value.series_id ]
        assert_equal 1, @courses.level_reads
      end
    end
  end
end
