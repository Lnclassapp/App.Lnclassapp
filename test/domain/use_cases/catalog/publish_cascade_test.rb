require "test_helper"

module UseCases
  module Catalog
    # ADR-0035, amendement du 2026-10-01 : « Tout publier » enchaîne les use cases de publication existants ; seuls les
    # brouillons descendent, un exercice sans question complète reste en brouillon et se compte, une fiche d'un cours non
    # publié est refusée sans rien écrire.
    class PublishCascadeTest < ActiveSupport::TestCase
      Course = Entities::Catalog::Course
      Essential = Entities::Catalog::Essential

      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        def initialize(*courses) = @stored = courses
        def find_by_slug(slug:) = @stored.find { it.slug == slug }
      end

      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        def initialize(*essentials, drafts: {})
          @stored = essentials
          @drafts = drafts
        end

        def find_by_slug(slug:) = @stored.find { it.slug == slug }
        def draft_slugs(course_id:) = @drafts.fetch(course_id, [])
      end

      class FakeExercises
        include Ports::Assessment::ExerciseRepositoryPort

        attr_reader :asked

        def initialize(drafts) = (@drafts = drafts) && (@asked = [])

        def draft_public_ids(course_id: nil, essential_id: nil)
          @asked << { course_id:, essential_id: }.compact
          @drafts.fetch(course_id || essential_id, [])
        end
      end

      # Un use case de publication : il note chaque appel, et répond l'échec prévu pour certaines clés.
      class FakePublish
        attr_reader :calls

        def initialize(refusals = {}) = (@refusals = refusals) && (@calls = [])

        def call(actor:, **key)
          @calls << [ actor.user_id, key.values.first ]
          reason = @refusals[key.values.first]
          reason ? Shared::Result.failure(:conflict, errors: { base: [ reason ] }) : Shared::Result.success(key.values.first)
        end
      end

      setup do
        @courses = FakeCourses.new(Course.new(id: 1, slug: "genetique", name: "Génétique", status: "draft"),
                                   Course.new(id: 2, slug: "publie", name: "Publié", status: "published"))
        @essentials = FakeEssentials.new(
          Essential.new(id: 10, slug: "meiose", course_id: 1, name: "La méiose", status: "draft", course_status: "published"),
          Essential.new(id: 11, slug: "orpheline", course_id: 3, name: "Orpheline", status: "draft", course_status: "draft"),
          drafts: { 1 => %w[meiose mitose] }
        )
        @exercises = FakeExercises.new({ 1 => %w[ex-a ex-b ex-c], 10 => %w[ex-a] })
        @publish_course = FakePublish.new
        @publish_essential = FakePublish.new({ "orpheline" => :parent_not_published })
        @publish_exercise = FakePublish.new({ "ex-b" => :not_publishable })
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def cascade(root, slug, actor: @team)
        PublishCascade.new(courses: @courses, essentials: @essentials, exercises: @exercises, publish_course: @publish_course,
                           publish_essential: @publish_essential, publish_exercise: @publish_exercise,
                           transaction: @transaction, policy: Policies::Catalog::ManageContentPolicy.new)
                      .call(actor:, root:, slug:)
      end

      test "un cours brouillon : le cours, puis ses fiches brouillons, puis les exercices brouillons de ses fiches publiées" do
        result = cascade(:course, "genetique")

        assert result.success?
        assert_equal [ [ 7, "genetique" ] ], @publish_course.calls
        assert_equal [ [ 7, "meiose" ], [ 7, "mitose" ] ], @publish_essential.calls
        assert_equal [ [ 7, "ex-a" ], [ 7, "ex-b" ], [ 7, "ex-c" ] ], @publish_exercise.calls
        assert_equal [ { course_id: 1 } ], @exercises.asked
        assert_equal [ "genetique", 2, 2, 1 ], [ result.value.root.slug, result.value.essentials, result.value.exercises, result.value.skipped ]
        assert_equal 1, @transaction.calls
      end

      test "un cours déjà publié n'est pas republié ; ses brouillons le sont" do
        @essentials = FakeEssentials.new(drafts: { 2 => %w[nouvelle] })
        @exercises = FakeExercises.new({ 2 => %w[ex-z] })

        result = cascade(:course, "publie")

        assert_empty @publish_course.calls
        assert_equal [ [ 7, "nouvelle" ] ], @publish_essential.calls
        assert_equal [ 1, 1, 0 ], [ result.value.essentials, result.value.exercises, result.value.skipped ]
      end

      test "une fiche : elle, puis ses exercices brouillons ; aucune autre fiche" do
        result = cascade(:essential, "meiose")

        assert_equal [ [ 7, "meiose" ] ], @publish_essential.calls
        assert_equal [ { essential_id: 10 } ], @exercises.asked
        assert_equal [ [ 7, "ex-a" ] ], @publish_exercise.calls
        assert_empty @publish_course.calls
        assert_equal [ "meiose", 0, 1, 0 ], [ result.value.root.slug, result.value.essentials, result.value.exercises, result.value.skipped ]
      end

      test "une fiche d'un cours non publié est refusée avec sa raison, et rien d'autre n'est tenté" do
        result = cascade(:essential, "orpheline")

        assert_equal :conflict, result.code
        assert_equal [ :parent_not_published ], result.errors.fetch(:base)
        assert_empty @exercises.asked
        assert_empty @publish_exercise.calls
      end

      test "hors de l'équipe de contenu : interdit ; une racine inconnue : introuvable ; un type inconnu : erreur de programmation" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher)

        assert_equal :forbidden, cascade(:course, "genetique", actor: teacher).code
        assert_equal :not_found, cascade(:course, "inconnu").code
        assert_equal :not_found, cascade(:essential, "inconnue").code
        assert_raises(ArgumentError) { cascade(:exercise, "ex-a") }
        assert_empty @publish_course.calls
        assert_equal 0, @transaction.calls
      end
    end
  end
end
