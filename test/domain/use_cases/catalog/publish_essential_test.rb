require "test_helper"

module UseCases
  module Catalog
    class PublishEssentialTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 12)
      Clock = Data.define(:now)
      Essential = Entities::Catalog::Essential

      # Comme le repository : la transition pose le statut ; la fiche relue le porte.
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
          Essential.new(id: 10, slug: "brouillon", course_id: 1, name: "Brouillon", status: "draft", course_status: "published"),
          Essential.new(id: 11, slug: "archivee", course_id: 1, name: "Archivée", status: "archived", course_status: "published"),
          Essential.new(id: 12, slug: "publiee", course_id: 1, name: "Publiée", status: "published", course_status: "published"),
          Essential.new(id: 13, slug: "cours-brouillon", course_id: 2, name: "Cours brouillon", status: "draft", course_status: "draft"),
          Essential.new(id: 14, slug: "cours-archive", course_id: 3, name: "Cours archivé", status: "archived", course_status: "archived")
        )
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @team = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def publish(slug, actor: @team)
        PublishEssential.new(essentials: @essentials, audit_log: @audit_log, transaction: @transaction,
                             policy: Policies::Catalog::ManageContentPolicy.new, clock: Clock.new(NOW)).call(actor:, slug:)
      end

      test "publie une fiche brouillon d'un cours publié, relue avec son nouveau statut, et l'inscrit au journal" do
        result = publish("brouillon")

        assert result.success?
        assert_equal [ "brouillon", "published" ], [ result.value.slug, result.value.status ]
        assert_equal [ [ 10, "published", NOW ] ], @essentials.transitions
        assert_equal [ { action: "content.published", actor_id: 7, at: NOW, subject_type: "Essential", subject_id: 10,
                         metadata: { slug: "brouillon" } } ], @audit_log.records
        assert_equal 1, @transaction.calls
      end

      test "une fiche archivée se republie" do
        assert_equal "published", publish("archivee").value.status
      end

      test "publier une fiche d'un cours brouillon ou archivé est refusé (ADR-0035)" do
        [ "cours-brouillon", "cours-archive" ].each do |slug|
          result = publish(slug)

          assert_equal [ :conflict, { base: [ :parent_not_published ] } ], [ result.code, result.errors ]
        end
        assert_empty @essentials.transitions
        assert_empty @audit_log.records
      end

      test "une fiche déjà publiée ne se publie pas une seconde fois" do
        result = publish("publiee")

        assert_equal [ :conflict, { base: [ :transition_not_allowed ] } ], [ result.code, result.errors ]
        assert_equal 0, @transaction.calls
      end

      test "hors équipe, rien ne change, même pour une fiche inconnue" do
        [ Entities::Identity::Actor.new(user_id: 8, role: :teacher, school_id: 3),
          Entities::Identity::Actor.new(user_id: 9, role: :student), nil ].each do |actor|
          assert_equal :forbidden, publish("brouillon", actor:).code
          assert_equal :forbidden, publish("inconnue", actor:).code
        end
        assert_empty @essentials.transitions
      end

      test "une fiche inconnue est introuvable" do
        assert_equal :not_found, publish("inconnue").code
      end
    end
  end
end
