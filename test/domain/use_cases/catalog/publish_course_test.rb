require "test_helper"

module UseCases
  module Catalog
    class PublishCourseTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Course = Entities::Catalog::Course

      # Comme le repository : la transition écrit le statut, relu ensuite par find_by_slug.
      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        attr_reader :transitions

        def initialize(courses)
          @courses = courses
          @transitions = []
        end

        def find_by_slug(slug:) = @courses.find { it.slug == slug }&.dup

        def transition(id:, to:, at:)
          @transitions << [ id, to, at ]
          @courses.find { it.id == id }.status = to
          true
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :entries

        def initialize
          @entries = []
        end

        def record(**entry) = (@entries << entry) && true
      end

      setup do
        @courses = FakeCourses.new(%w[draft published archived].each_with_index.map do |status, index|
          Course.new(id: index + 1, slug: status, name: status.capitalize, status:)
        end)
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def publish(slug, actor: @team)
        PublishCourse.new(courses: @courses, audit_log: @audit_log, transaction: @transaction,
                          policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                     .call(actor:, slug:)
      end

      test "publier un brouillon écrit la transition et journalise content.published, dans une transaction" do
        result = publish("draft")

        assert result.success?
        assert_equal [ "draft", "published" ], [ result.value.slug, result.value.status ]
        assert_equal [ [ 1, "published", NOW ] ], @courses.transitions
        assert_equal [ { action: "content.published", actor_id: 7, subject_type: "Course", subject_id: 1,
                         metadata: { slug: "draft", from: "draft" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un cours archivé se republie" do
        assert_equal "published", publish("archived").value.status
        assert_equal [ [ 3, "published", NOW ] ], @courses.transitions
      end

      test "un cours déjà publié : :conflict, rien n'est écrit" do
        result = publish("published")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :transition_not_allowed ] }, result.errors)
        assert_empty @courses.transitions
        assert_empty @audit_log.entries
      end

      test "hors de l'équipe : :forbidden ; un cours inconnu : :not_found" do
        teacher = Entities::Identity::Actor.new(user_id: 3, role: :teacher, school_id: 1)

        assert_equal :forbidden, publish("draft", actor: teacher).code
        assert_equal :forbidden, publish("inconnu", actor: nil).code
        assert_equal :not_found, publish("inconnu").code
        assert_empty @courses.transitions
      end
    end
  end
end
