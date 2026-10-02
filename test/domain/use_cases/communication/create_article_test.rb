require "test_helper"

# ADR-0073 §4.2, §4.3 : l'équipe admin ou content crée un article en brouillon, dont elle est l'autrice ; le geste est
# au journal (BL-07). Hors de ces sous-rôles, rien n'est écrit (BL-08).
module UseCases
  module Communication
    class CreateArticleTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 10, 5, 9)
      Clock = Data.define(:now)
      Article = Entities::Communication::Article

      # Comme l'adaptateur : un brouillon, slug tiré du titre ; une couverture inconnue est refusée.
      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        attr_reader :created

        def initialize
          @created = []
        end

        def create(dto:, author_id:, at:)
          return Shared::Result.failure(:invalid, errors: { cover_public_id: [ :invalid ] }) if dto.cover_public_id == "inconnue"

          @created << [ dto, author_id, at ]
          Shared::Result.success(Article.new(id: 4, public_id: "art00000000004", slug: dto.title.parameterize, title: dto.title,
                                             status: "draft", signature: dto.signature, author_id:))
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
        @articles = FakeArticles.new
        @audit_log = FakeAuditLog.new
        @transaction = FakeTransaction.new
        @content = Entities::Identity::Actor.new(user_id: 7, role: :team, team_role: "content")
      end

      def create(actor: @content, **attributes)
        dto = Dtos::Communication::ArticleInput.new(title: "Réviser le BEPC en 4 semaines", body: "<div>Un plan.</div>", **attributes)
        CreateArticle.new(articles: @articles, audit_log: @audit_log, transaction: @transaction,
                          policy: Policies::Communication::ManageArticlesPolicy.new, clock: Clock.new(NOW))
                     .call(actor:, dto:)
      end

      test "BL-07 : un membre content crée un brouillon dont il est l'auteur ; article.created au journal, dans une transaction" do
        result = create

        assert result.success?
        assert_equal [ "reviser-le-bepc-en-4-semaines", "draft" ], [ result.value.slug, result.value.status ]
        dto, author_id, at = @articles.created.sole
        assert_equal [ "Réviser le BEPC en 4 semaines", 7, NOW ], [ dto.title, author_id, at ]
        assert_equal [ { action: "article.created", actor_id: 7, subject_type: "Article", subject_id: 4,
                         metadata: { public_id: "art00000000004" }, at: NOW } ], @audit_log.entries
        assert_equal 1, @transaction.calls
      end

      test "BL-07 : un membre admin crée aussi un brouillon" do
        admin = Entities::Identity::Actor.new(user_id: 2, role: :team, team_role: "admin")

        assert create(actor: admin).success?
        assert_equal 2, @articles.created.sole[1]
      end

      test "BL-08 : terrain, enseignant, direction, élève, visiteur : :forbidden, rien n'est écrit, avant même la saisie" do
        outsiders = [ Entities::Identity::Actor.new(user_id: 3, role: :team, team_role: "field"),
                      Entities::Identity::Actor.new(user_id: 4, role: :teacher, school_id: 1),
                      Entities::Identity::Actor.new(user_id: 5, role: :school_admin, school_id: 1),
                      Entities::Identity::Actor.new(user_id: 6, role: :student), nil ]

        outsiders.each { assert_equal :forbidden, create(actor: it, title: "").code }
        assert_empty @articles.created
        assert_empty @audit_log.entries
      end

      test "une saisie invalide donne :invalid avec les erreurs du formulaire ; rien n'est écrit" do
        result = create(title: " ", signature: "moi")

        assert_equal :invalid, result.code
        assert_equal %i[title signature], result.errors.keys
        assert_empty @articles.created
        assert_empty @audit_log.entries
      end

      test "une couverture refusée par l'adaptateur : :invalid nommant la couverture, rien au journal" do
        result = create(cover_public_id: "inconnue")

        assert_equal :invalid, result.code
        assert_equal({ cover_public_id: [ :invalid ] }, result.errors)
        assert_empty @audit_log.entries
      end
    end
  end
end
