require "test_helper"

# ADR-0073 §4.2 : l'équipe archive un article publié (son lien répondra 410) ; le geste est au journal (BL-07). Une
# transition déjà faite ou interdite est un :conflict.
module UseCases
  module Communication
    class ArchiveArticleTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 8, 16)
      Clock = Data.define(:now)
      Article = Entities::Communication::Article

      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        attr_reader :transitions

        def initialize(articles)
          @articles = articles
          @transitions = []
        end

        def find_by_public_id(public_id:) = (@read_before || @articles).find { it.public_id == public_id }&.dup

        # Like the adapter: only from a departure state admitted for to; false otherwise (a concurrent gesture did it).
        def transition(id:, to:, at:)
          article = live(id)
          return false unless Entities::Shared::ContentStatus::TRANSITIONS.fetch(article.status).include?(to)

          @transitions << [ id, to, at ]
          article.status = to
          article.archived_at = at
          true
        end

        def live(id) = @articles.find { it.id == id }

        # From now on, every gesture reads the articles as they are now: as if all had read before any wrote.
        def read_before_writes! = @read_before = @articles.map(&:dup)
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
        @articles = FakeArticles.new(%w[draft published archived].each_with_index.map do |status, index|
          Article.new(id: index + 1, public_id: "art0000000000#{index + 1}", slug: "article-#{status}", title: status,
                      signature: "team", status:)
        end)
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @content = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def archive(public_id, actor: @content, now: NOW)
        ArchiveArticle.new(articles: @articles, audit_log: @audit_log, transaction: @transaction,
                           policy: Policies::Communication::ManageArticlesPolicy.new, clock: Clock.new(now))
                      .call(actor:, public_id:)
      end

      test "BL-07 : un article publié est archivé et relu ; article.archived au journal, dans une transaction" do
        result = archive("art00000000002")

        assert result.success?
        assert_equal [ "archived", NOW ], [ result.value.status, result.value.archived_at ]
        assert_equal [ [ 2, "archived", NOW ] ], @articles.transitions
        assert_equal [ { action: "article.archived", actor_id: 7, subject_type: "Article", subject_id: 2,
                         metadata: { public_id: "art00000000002", from: "published" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un brouillon ou un article déjà archivé : :conflict, rien n'est écrit" do
        %w[art00000000001 art00000000003].each do |public_id|
          result = archive(public_id)

          assert_equal :conflict, result.code
          assert_equal({ base: [ :transition_not_allowed ] }, result.errors)
        end
        assert_empty @articles.transitions
        assert_empty @audit_log.entries
      end

      test "deux archivages simultanés : le second, qui a lu l'article publié, reçoit :conflict ; archived_at et le journal gardent le premier" do
        @articles.read_before_writes!

        first = archive("art00000000002")
        second = archive("art00000000002", now: NOW + 60)

        assert first.success?
        assert_equal :conflict, second.code
        assert_equal({ base: [ :transition_not_allowed ] }, second.errors)
        assert_equal NOW, @articles.live(2).archived_at
        assert_equal [ "article.archived" ], @audit_log.entries.map { it[:action] }
      end

      test "BL-08 : hors de l'équipe admin ou content : :forbidden ; un article inconnu : :not_found" do
        field = Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "field")

        assert_equal :forbidden, archive("art00000000002", actor: field).code
        assert_equal :forbidden, archive("inconnu", actor: nil).code
        assert_equal :not_found, archive("inconnu").code
        assert_empty @articles.transitions
      end
    end
  end
end
