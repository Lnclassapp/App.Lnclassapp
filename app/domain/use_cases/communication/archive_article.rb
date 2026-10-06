# 🧠 DOMAINE · UseCases::Communication::ArchiveArticle
# Rôle : l'équipe archive un article publié : son adresse répond 410, il se remet en ligne ; geste au journal
# ADR  : 0026, 0028, 0035, 0074 · UDR : 0067
module UseCases
  module Communication
    class ArchiveArticle
      def initialize(articles:, audit_log:, transaction:, policy:, clock:)
        @articles = articles
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Article relu, archivé) | :forbidden | :not_found | :conflict (base: transition_not_allowed)
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        article = @articles.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if article.nil?

        transition = Entities::Shared::ContentStatus.transition(from: article.status, to: "archived", parent_published: true)
        return transition if transition.failure?

        moved = @transaction.call do
          now = @clock.now
          next false unless @articles.transition(id: article.id, to: transition.value, at: now)

          @audit_log.record(action: "article.archived", actor_id: actor.user_id, subject_type: "Article", subject_id: article.id,
                            metadata: { public_id:, from: article.status }, at: now)
          true
        end
        # Un geste concurrent l'a déjà fait entre la lecture et l'écriture : rien n'est réécrit ni journalisé.
        return Shared::Result.failure(:conflict, errors: { base: [ :transition_not_allowed ] }) unless moved

        Shared::Result.success(@articles.find_by_public_id(public_id:))
      end
    end
  end
end
