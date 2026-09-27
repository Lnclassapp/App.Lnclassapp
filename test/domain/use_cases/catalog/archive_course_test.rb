require "test_helper"

module UseCases
  module Catalog
    class ArchiveCourseTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Course = Entities::Catalog::Course

      # Ce faux n'a que find_by_slug et transition : archiver ne touche ni aux fiches ni aux assignations.
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

      def archive(slug, actor: @team)
        ArchiveCourse.new(courses: @courses, audit_log: @audit_log, transaction: @transaction,
                          policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                     .call(actor:, slug:)
      end

      test "archiver un cours publié écrit la transition et journalise content.archived, dans une transaction" do
        result = archive("published")

        assert result.success?
        assert_equal "archived", result.value.status
        assert_equal [ [ 2, "archived", NOW ] ], @courses.transitions
        assert_equal [ { action: "content.archived", actor_id: 7, subject_type: "Course", subject_id: 2,
                         metadata: { slug: "published", from: "published" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un brouillon ou un cours déjà archivé ne s'archive pas : :conflict" do
        assert_equal({ base: [ :transition_not_allowed ] }, archive("draft").errors)
        assert_equal :conflict, archive("archived").code
        assert_empty @courses.transitions
        assert_empty @audit_log.entries
      end

      test "hors de l'équipe : :forbidden ; un cours inconnu : :not_found" do
        student = Entities::Identity::Actor.new(user_id: 5, role: :student)

        assert_equal :forbidden, archive("published", actor: student).code
        assert_equal :forbidden, archive("inconnu", actor: nil).code
        assert_equal :not_found, archive("inconnu").code
        assert_empty @courses.transitions
      end
    end
  end
end
