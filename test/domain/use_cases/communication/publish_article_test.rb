require "test_helper"

# ADR-0073 §4.2 : publier exige un article complet (BL-09, BL-13) ; une remise en ligne garde la date de la première
# publication (BL-11) ; le geste est au journal, la remise en ligne dite (BL-07).
module UseCases
  module Communication
    class PublishArticleTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 12, 8)
      FIRST_PUBLISHED = Time.utc(2026, 10, 5, 9)
      Clock = Data.define(:now)
      Article = Entities::Communication::Article
      ArticleImage = Entities::Communication::ArticleImage

      # Comme l'adaptateur : published_at = COALESCE(published_at, at), archived_at remis à nil, relu ensuite.
      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        attr_reader :transitions

        def initialize(articles)
          @articles = articles
          @transitions = []
        end

        def find_by_public_id(public_id:) = @articles.find { it.public_id == public_id }&.dup

        def transition(id:, to:, at:)
          @transitions << [ id, to, at ]
          article = @articles.find { it.id == id }
          article.status = to
          article.published_at ||= at
          article.archived_at = nil
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

      def article(id, status, **attributes)
        Article.new(id:, public_id: "art0000000000#{id}", slug: "article-#{id}", title: "Réviser le BEPC",
                    excerpt: "Un plan semaine par semaine.", body: "<div>Commencez par les maths.</div>", signature: "team",
                    status:, **attributes)
      end

      setup do
        @articles = FakeArticles.new([
          article(1, "draft"),
          article(2, "draft", excerpt: nil),
          article(3, "draft", cover: ArticleImage.new(public_id: "cov00000000001"), cover_alt: "Des élèves",
                              images: [ ArticleImage.new(public_id: "img00000000001", alt: "Une salle"),
                                        ArticleImage.new(public_id: "img00000000002") ]),
          article(4, "archived", published_at: FIRST_PUBLISHED, archived_at: Time.utc(2026, 10, 8)),
          article(5, "published", published_at: FIRST_PUBLISHED)
        ])
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @admin = Entities::Identity::Actor.new(user_id: 2, role: :team, team_role: "admin")
      end

      def publish(public_id, actor: @admin)
        PublishArticle.new(articles: @articles, audit_log: @audit_log, transaction: @transaction,
                           policy: Policies::Communication::ManageArticlesPolicy.new, clock: Clock.new(NOW))
                      .call(actor:, public_id:)
      end

      test "BL-07 : un brouillon complet est publié et relu ; article.published au journal, dans une transaction" do
        result = publish("art00000000001")

        assert result.success?
        assert_equal [ "published", NOW ], [ result.value.status, result.value.published_at ]
        assert_equal [ [ 1, "published", NOW ] ], @articles.transitions
        assert_equal [ { action: "article.published", actor_id: 2, subject_type: "Article", subject_id: 1,
                         metadata: { public_id: "art00000000001", from: "draft", republished: false }, at: NOW } ],
                     @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "BL-09 : un brouillon sans résumé → :invalid nommant excerpt ; il reste brouillon, rien au journal" do
        result = publish("art00000000002")

        assert_equal :invalid, result.code
        assert_equal [ "Écrivez le résumé : il est obligatoire pour publier." ], result.errors[:excerpt]
        assert_empty @articles.transitions
        assert_equal "draft", @articles.find_by_public_id(public_id: "art00000000002").status
        assert_empty @audit_log.entries
      end

      test "BL-13 : une image du texte sans texte de remplacement → :invalid nommant l'image et son numéro" do
        result = publish("art00000000003")

        assert_equal :invalid, result.code
        assert_equal [ :"image_alts.img00000000002" ], result.errors.keys
        assert_equal [ "Saisissez le texte de remplacement de l'image 2 : il est obligatoire pour publier." ],
                     result.errors[:"image_alts.img00000000002"]
        assert_empty @articles.transitions
      end

      test "BL-11 : un article archivé remis en ligne garde sa date de publication ; le journal dit republished" do
        result = publish("art00000000004")

        assert_equal [ "published", FIRST_PUBLISHED, nil ],
                     [ result.value.status, result.value.published_at, result.value.archived_at ]
        assert_equal({ public_id: "art00000000004", from: "archived", republished: true }, @audit_log.entries.sole[:metadata])
      end

      test "un article déjà publié : :conflict, rien n'est écrit" do
        result = publish("art00000000005")

        assert_equal :conflict, result.code
        assert_equal({ base: [ :transition_not_allowed ] }, result.errors)
        assert_empty @articles.transitions
        assert_empty @audit_log.entries
      end

      test "BL-08 : hors de l'équipe admin ou content : :forbidden ; un article inconnu : :not_found" do
        field = Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "field")

        assert_equal :forbidden, publish("art00000000001", actor: field).code
        assert_equal :forbidden, publish("inconnu", actor: nil).code
        assert_equal :not_found, publish("inconnu").code
        assert_empty @articles.transitions
      end
    end
  end
end
