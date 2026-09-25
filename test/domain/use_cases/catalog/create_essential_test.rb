require "test_helper"

module UseCases
  module Catalog
    class CreateEssentialTest < ActiveSupport::TestCase
      Course = Entities::Catalog::Course
      Essential = Entities::Catalog::Essential

      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        def initialize(*courses)
          @courses = courses
        end

        def find_by_slug(slug:) = @courses.find { it.slug == slug }
      end

      # Comme le repository : nom unique dans le cours (index), slug tiré du cours et de la fiche, position suivante.
      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        attr_reader :stored

        def initialize(*essentials)
          @stored = essentials
        end

        def next_position(course_id:) = @stored.select { it.course_id == course_id }.map(&:position).max.to_i + 1

        def create(essential:)
          if @stored.any? { it.course_id == essential.course_id && it.name == essential.name }
            return Shared::Result.failure(:conflict, errors: { name: [ :taken ] })
          end

          essential.id = 500 + @stored.size
          essential.slug = essential.name.parameterize
          @stored << essential
          Shared::Result.success(essential)
        end
      end

      setup do
        @courses = FakeCourses.new(Course.new(id: 1, slug: "genetique", name: "Génétique", status: "published"),
                                   Course.new(id: 2, slug: "optique", name: "Optique", status: "draft"))
        @essentials = FakeEssentials.new(Essential.new(id: 10, course_id: 1, name: "La méiose", position: 1, status: "published"),
                                         Essential.new(id: 11, course_id: 1, name: "La mitose", position: 4, status: "draft"),
                                         Essential.new(id: 12, course_id: 2, name: "Les lentilles", position: 9, status: "draft"))
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(actor: @team, course_slug: "genetique", **attributes)
        dto = Dtos::Catalog::EssentialInput.new(course_slug:, name: "Brassage Génétique", subtitle: "Par la méiose",
                                                content: "<div><strong>À retenir</strong></div>", **attributes)
        CreateEssential.new(courses: @courses, essentials: @essentials, transaction: @transaction,
                            policy: Policies::Catalog::ManageContentPolicy.new).call(actor:, dto:)
      end

      test "crée la fiche en brouillon à la suite du cours, son auteur étant l'acteur, sans changer la casse du nom" do
        result = create

        assert result.success?
        essential = result.value
        assert_equal [ 1, "Brassage Génétique", "Par la méiose", "<div><strong>À retenir</strong></div>", "draft", 5, 7 ],
                     [ essential.course_id, essential.name, essential.subtitle, essential.content, essential.status,
                       essential.position, essential.author_id ]
        assert_equal "published", essential.course_status
        assert_equal 1, @transaction.calls
      end

      test "dans un cours encore vide, la fiche prend la première position ; un cours brouillon en reçoit aussi" do
        empty = FakeCourses.new(Course.new(id: 3, slug: "vide", name: "Vide", status: "draft"))
        result = CreateEssential.new(courses: empty, essentials: @essentials, transaction: @transaction,
                                     policy: Policies::Catalog::ManageContentPolicy.new)
                                .call(actor: @team, dto: Dtos::Catalog::EssentialInput.new(course_slug: "vide", name: "Première"))

        assert_equal [ 1, "draft", nil ], [ result.value.position, result.value.status, result.value.subtitle ]
      end

      test "un enseignant, un élève ou un visiteur est refusé, même pour un cours inconnu, et rien n'est écrit" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3),
          Entities::Identity::Actor.new(user_id: 9, role: :student), nil ].each do |actor|
          assert_equal :forbidden, create(actor:).code
          assert_equal :forbidden, create(actor:, course_slug: "inconnu").code
        end
        assert_equal 3, @essentials.stored.size
        assert_equal 0, @transaction.calls
      end

      test "un cours inconnu est introuvable" do
        assert_equal :not_found, create(course_slug: "inconnu").code
        assert_equal 0, @transaction.calls
      end

      test "une saisie invalide est refusée sans rien écrire" do
        result = create(name: "", subtitle: "b" * 151)

        assert_equal [ :invalid, %i[name subtitle] ], [ result.code, result.errors.keys.sort ]
        assert_equal 0, @transaction.calls
      end

      test "deux fiches du même cours ne portent pas le même nom ; un autre cours l'accepte" do
        taken = create(name: "La méiose")

        assert_equal [ :conflict, { name: [ :taken ] } ], [ taken.code, taken.errors ]
        assert create(course_slug: "optique", name: "La méiose").success?
      end
    end
  end
end
