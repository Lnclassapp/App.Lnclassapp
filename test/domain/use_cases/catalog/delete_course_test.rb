require "test_helper"

module UseCases
  module Catalog
    # ADR-0136, CA-01, CA-02 (domaine) : l'équipe supprime une leçon sans activité d'élève,
    # la vérification se fait sous le verrou pris dans la transaction, et tout refus laisse la leçon intacte.
    class DeleteCourseTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 14, 12)
      Clock = Data.define(:now)
      Course = Entities::Catalog::Course
      Activity = Entities::Catalog::StudentActivity

      class FakeCourses
        include Ports::Catalog::CourseRepositoryPort

        attr_reader :calls

        def initialize(courses, activity:)
          @courses = courses
          @activity = activity
          @calls = []
        end

        def find_by_slug(slug:) = @courses.find { it.slug == slug }&.dup

        def lock_for_deletion(id:)
          @calls << [ :lock, id ]
          @activity
        end

        def delete(id:)
          @calls << [ :delete, id ]
          @courses.reject! { it.id == id }
          { courses: 1, essentials: 2 }
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
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def courses(activity: Activity.none)
        @courses ||= FakeCourses.new([ Course.new(id: 3, slug: "optique", name: "Optique", status: "published") ], activity:)
      end

      def delete(slug, actor: @team)
        DeleteCourse.new(courses: @courses, audit_log: @audit_log, transaction: @transaction,
                         policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW))
                    .call(actor:, slug:)
      end

      test "une leçon sans activité est supprimée sous verrou, dans une transaction, et content.deleted est journalisé" do
        courses

        result = delete("optique")

        assert result.success?
        assert_equal "optique", result.value.slug
        assert_equal [ [ :lock, 3 ], [ :delete, 3 ] ], @courses.calls
        assert_equal 1, @transaction.calls
        assert_equal [ { action: "content.deleted", actor_id: 7, subject_type: "Course", subject_id: 3,
                         metadata: { slug: "optique", name: "Optique", status: "published", deleted: { courses: 1, essentials: 2 } }, at: NOW } ],
                     @audit_log.entries
      end

      test "CA-01 : un acteur hors équipe est refusé avant toute lecture ; rien n'est verrouillé ni supprimé" do
        courses

        [ Entities::Identity::Actor.new(user_id: 9, role: :teacher), Entities::Identity::Actor.new(user_id: 9, role: :student), nil ].each do |actor|
          assert_equal :forbidden, delete("optique", actor:).code
        end
        assert_empty @courses.calls
        assert_empty @audit_log.entries
      end

      test "CA-02 : une activité d'élève, quelle qu'en soit la source, refuse la suppression ; rien n'est supprimé ni journalisé" do
        Activity.members.each do |source|
          @courses = nil
          @audit_log = FakeAuditLog.new
          courses(activity: Activity.none.with(source => 1))

          result = delete("optique")

          assert_equal :conflict, result.code, source
          assert_equal({ base: [ :student_activity ] }, result.errors, source)
          assert_equal [ [ :lock, 3 ] ], @courses.calls, source
          assert_empty @audit_log.entries, source
        end
      end

      test "une leçon supprimée entre la lecture et le verrou rend not_found, sans rien supprimer ni journaliser" do
        courses(activity: nil)

        assert_equal :not_found, delete("optique").code
        assert_equal [ [ :lock, 3 ] ], @courses.calls
        assert_empty @audit_log.entries
      end

      test "une leçon inconnue rend not_found sans verrou" do
        courses

        assert_equal :not_found, delete("absente").code
        assert_empty @courses.calls
      end
    end
  end
end
