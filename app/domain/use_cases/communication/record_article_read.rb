# 🧠 DOMAINE · UseCases::Communication::RecordArticleRead
# Rôle : compte la lecture d'un article publié, ni par l'équipe, ni par un robot, ni par un préchargement ; une panne du stockage ne lève pas
# ADR  : 0026, 0028, 0049, 0074 (§4.7)
module UseCases
  module Communication
    class RecordArticleRead
      # reporter : répond à report(error, handled: true, context:) (Rails.error, injecté par le contrôleur).
      # recoverable : la ou les classes d'erreur du stockage que le compteur avale (ActiveRecord::ActiveRecordError,
      # nommée par la delivery : le domaine ne connaît pas ActiveRecord). Toute autre erreur est un bogue et remonte.
      def initialize(articles:, policy:, reporter:, recoverable:)
        @articles = articles
        @policy = policy
        @reporter = reporter
        @recoverable = Array(recoverable)
      end

      # article : tout objet qui répond à id et status (la Detail de la query de lecture). headers : en-têtes lus par leur
      # nom. → Result(true : lecture comptée | false : non comptée) | :not_found (brouillon) | :expired (archivé)
      def call(actor:, article:, user_agent:, headers:)
        allowed = @policy.call(actor:, article:)
        return allowed if allowed.failure?
        # L'aperçu de l'équipe (brouillon, archivé) et toute lecture par l'équipe ne comptent pas.
        return Shared::Result.success(false) if article.status != "published" || actor&.team?
        return Shared::Result.success(false) unless Entities::Communication::ArticleRead.countable?(user_agent:, headers:)

        Shared::Result.success(@articles.increment_reads(article_id: article.id))
      rescue *@recoverable => error
        # Une panne du stockage ne bloque jamais la page (ADR-0074 §4.7) : elle est signalée, la lecture n'est pas comptée.
        @reporter.report(error, handled: true, context: { article_id: article.id })
        Shared::Result.success(false)
      end
    end
  end
end
