require "test_helper"

module UseCases
  module Catalog
    class ArchiveEssentialTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Essential = Entities::Catalog::Essential

      # Le port n'offre aucune suppression : archiver ne peut écrire que le statut de la fiche.
      class FakeEssentials
        include Ports::Catalog::EssentialRepositoryPort

        attr_reader :transitions

        def initialize(*essentials)
          @stored = essentials
          @transitions = []
        end

        def find_by_slug(slug:) = @stored.find { it.slug == slug }

        def transition(id:, to:, at:)
          @transitions << [ id, to, at ]
          @stored.find { it.id == id }.status = to
          true
        end
      end

      class FakeAuditLog
        include Ports::Identity::AuditLogPort

        attr_reader :records

        def initialize
          @records = []
        end

        def record(**entry) = (@records << entry) && true
      end

      setup do
        @essentials = FakeEssentials.new(
          Essential.new(id: 10, slug: "publiee", course_id: 1, name: "Publiée", status: "published", course_status: "published"),
          Essential.new(id: 11, slug: "cours-archive", course_id: 2, name: "Cours archivé", status: "published", course_status: "archived"),
          Essential.new(id: 12, slug: "brouillon", course_id: 1, name: "Brouillon", status: "draft", course_status: "published"),
          Essential.new(id: 13, slug: "archivee", course_id: 1, name: "Archivée", status: "archived", course_status: "published")
        )
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def archive(slug, actor: @team)
        ArchiveEssential.new(essentials: @essentials, audit_log: @audit_log, transaction: @transaction,
                             policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW)).call(actor:, slug:)
      end

      test "archive une fiche publiée, relue avec son nouveau statut, et l'inscrit au journal" do
        result = archive("publiee")

        assert result.success?
        assert_equal [ "publiee", "archived" ], [ result.value.slug, result.value.status ]
        assert_equal [ [ 10, "archived", NOW ] ], @essentials.transitions
        assert_equal [ { action: "content.archived", actor_id: 7, at: NOW, subject_type: "Essential", subject_id: 10,
                         metadata: { slug: "publiee" } } ], @audit_log.records
        assert_equal 1, @transaction.calls
      end

      test "une fiche publiée s'archive même si son cours ne l'est plus" do
        assert_equal "archived", archive("cours-archive").value.status
      end

      test "un brouillon ou une fiche déjà archivée ne s'archive pas" do
        [ "brouillon", "archivee" ].each do |slug|
          result = archive(slug)

          assert_equal [ :conflict, { base: [ :transition_not_allowed ] } ], [ result.code, result.errors ]
        end
        assert_empty @essentials.transitions
        assert_empty @audit_log.records
      end

      test "hors équipe, rien ne change, même pour une fiche inconnue" do
        teacher = Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3)

        assert_equal :forbidden, archive("publiee", actor: teacher).code
        assert_equal :forbidden, archive("inconnue", actor: nil).code
        assert_empty @essentials.transitions
      end

      test "une fiche inconnue est introuvable" do
        assert_equal :not_found, archive("inconnue").code
      end
    end
  end
end
