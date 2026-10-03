# 🧠 DOMAINE · UseCases::Communication::UpdateArticle
# Rôle : l'équipe modifie un article dans son état ; un article publié n'est jamais rendu incomplet ; geste au journal
# ADR  : 0026, 0028, 0029, 0035, 0073 · UDR : 0065
module UseCases
  module Communication
    class UpdateArticle
      def initialize(articles:, audit_log:, transaction:, policy:, clock:)
        @articles = articles
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Communication::ArticleInput, dont images (les images du texte) est posé par l'appelant.
      # → Result(Article) | :forbidden | :not_found | :invalid (saisie, règle de publication d'un article publié, couverture)
      def call(actor:, public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @articles.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # ADR-0073 §4.2 : un article en ligne ne perd jamais son résumé ni un texte de remplacement par une modification.
        if current.published?
          errors = dto.to_article(status: current.status).publication_errors
          return Shared::Result.failure(:invalid, errors:) if errors.any?
        end

        @transaction.call { update(actor, current, dto) }
      end

      private

      def update(actor, current, dto)
        now = @clock.now
        updated = @articles.update(id: current.id, dto:, at: now)
        if updated.success?
          @audit_log.record(action: "article.updated", actor_id: actor.user_id, subject_type: "Article", subject_id: current.id,
                            metadata: { public_id: current.public_id, status: current.status }, at: now)
        end
        updated
      end
    end
  end
end
