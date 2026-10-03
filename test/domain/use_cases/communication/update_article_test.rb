require "test_helper"

# ADR-0073 §4.2 : l'équipe modifie un article dans son état ; un article publié n'est jamais rendu incomplet par une
# modification (mêmes règles que la publication). Le geste est au journal (BL-07).
module UseCases
  module Communication
    class UpdateArticleTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 6, 14)
      Clock = Data.define(:now)
      Article = Entities::Communication::Article
      Image = Dtos::Communication::ArticleInput::Image

      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        attr_reader :updates

        def initialize(articles)
          @articles = articles
          @updates = []
        end

        def find_by_public_id(public_id:) = @articles.find { it.public_id == public_id }

        def update(id:, dto:, at:)
          return Shared::Result.failure(:invalid, errors: { cover_public_id: [ :invalid ] }) if dto.cover_public_id == "inconnue"

          @updates << [ id, dto, at ]
          article = @articles.find { it.id == id }
          Shared::Result.success(Article.new(id:, public_id: article.public_id, slug: article.slug, title: dto.title,
                                             status: article.status, signature: dto.signature))
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
        @articles = FakeArticles.new(%w[draft published archived].each_with_index.map do |status, index|
          Article.new(id: index + 1, public_id: "art0000000000#{index + 1}", slug: "article-#{status}", title: "Ancien titre",
                      excerpt: "Le résumé.", body: "<div>Le texte.</div>", signature: "team", status:)
        end)
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @content = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def update(public_id, actor: @content, **attributes)
        dto = Dtos::Communication::ArticleInput.new(title: "Réviser le BEPC", excerpt: "Un plan semaine par semaine.",
                                                    body: "<div>Commencez par les maths.</div>", signature: "author", **attributes)
        UpdateArticle.new(articles: @articles, audit_log: @audit_log, transaction: @transaction,
                          policy: Policies::Communication::ManageArticlesPolicy.new, clock: Clock.new(NOW))
                     .call(actor:, public_id:, dto:)
      end

      test "BL-07 : un brouillon modifié garde son état ; article.updated au journal, dans une transaction" do
        result = update("art00000000001")

        assert result.success?
        assert_equal [ "Réviser le BEPC", "draft", "article-draft" ], [ result.value.title, result.value.status, result.value.slug ]
        id, dto, at = @articles.updates.sole
        assert_equal [ 1, "author", NOW ], [ id, dto.signature, at ]
        assert_equal [ { action: "article.updated", actor_id: 7, subject_type: "Article", subject_id: 1,
                         metadata: { public_id: "art00000000001", status: "draft" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "un brouillon s'enregistre incomplet : sans résumé, sans texte, image sans texte de remplacement" do
        result = update("art00000000001", excerpt: "", body: "",
                                          images: [ Image.new(public_id: "img00000000001", sgid: "s", url: "/u", alt: nil) ])

        assert result.success?
        assert_equal 1, @articles.updates.size
      end

      test "ADR-0073 §4.2 : un article publié dont on vide le résumé → :invalid nommant excerpt ; rien n'est écrit" do
        result = update("art00000000002", excerpt: "  ")

        assert_equal :invalid, result.code
        assert_equal [ "Écrivez le résumé : il est obligatoire pour publier." ], result.errors[:excerpt]
        assert_empty @articles.updates
        assert_empty @audit_log.entries
      end

      test "un article publié dont une image du texte perd son texte de remplacement → :invalid nommant l'image" do
        images = [ Image.new(public_id: "img00000000001", sgid: "s1", url: "/u1", alt: "Une salle"),
                   Image.new(public_id: "img00000000002", sgid: "s2", url: "/u2", alt: nil) ]

        result = update("art00000000002", images:, image_alts: { "img00000000001" => "Une salle", "img00000000002" => " " })

        assert_equal :invalid, result.code
        assert_equal [ :"image_alts.img00000000002" ], result.errors.keys
        assert_empty @articles.updates
      end

      test "un article publié complet s'enregistre ; le journal dit son état" do
        result = update("art00000000002")

        assert result.success?
        assert_equal({ public_id: "art00000000002", status: "published" }, @audit_log.entries.sole[:metadata])
      end

      test "un article archivé s'enregistre sans la règle de publication" do
        assert update("art00000000003", excerpt: nil).success?
      end

      test "hors de l'équipe admin ou content : :forbidden ; un article inconnu : :not_found ; rien n'est écrit" do
        field = Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "field")

        assert_equal :forbidden, update("art00000000001", actor: field).code
        assert_equal :forbidden, update("inconnu", actor: nil).code
        assert_equal :not_found, update("inconnu").code
        assert_empty @articles.updates
        assert_empty @audit_log.entries
      end

      test "une saisie invalide, ou une couverture refusée par l'adaptateur : :invalid, rien au journal" do
        assert_equal %i[title], update("art00000000001", title: "").errors.keys
        assert_equal({ cover_public_id: [ :invalid ] }, update("art00000000001", cover_public_id: "inconnue").errors)
        assert_empty @audit_log.entries
      end
    end
  end
end
