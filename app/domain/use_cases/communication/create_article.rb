# 🧠 DOMAINE · UseCases::Communication::CreateArticle
# Rôle : l'équipe admin ou content crée un article du blog en brouillon, dont elle est l'autrice ; geste au journal
# ADR  : 0026, 0028, 0035, 0073 · UDR : 0065
module UseCases
  module Communication
    class CreateArticle
      def initialize(articles:, audit_log:, transaction:, policy:, clock:)
        @articles = articles
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Communication::ArticleInput. → Result(Article) | :forbidden | :invalid (saisie, couverture inconnue)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        @transaction.call do
          now = @clock.now
          created = @articles.create(dto:, author_id: actor.user_id, at: now)
          if created.success?
            @audit_log.record(action: "article.created", actor_id: actor.user_id, subject_type: "Article",
                              subject_id: created.value.id, metadata: { public_id: created.value.public_id }, at: now)
          end
          created
        end
      end
    end
  end
end
